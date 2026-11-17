# Builds the import package "SiteManagement - Import rows" (route 2 of the import working method, Eddy 17-11-2026).
# Base = Eddy's latest export of "SiteManagement - Export file" (Incoming/Flows, gitignored): same SharePoint connection.
# Changed vs base: definition.json (new flow), display name in the manifests, OneDrive connection removed (unused).
# v2 (17-11-2026): flat structure; Power Automate allows nesting level <= 8, this flow stays <= 6
# (artifacts/Test-FlowNesting.ps1). Per row: composes + one Switch; counters derived from the log after the loop.
# Output: artifacts/flows/SiteManagement-Import-rows-v2.zip (gitignored) + sanitized flows/SiteManagement-Import-rows.definition.json.
# Run from the repo root: py -E -P flows/make_import_rows_package.py
import copy, glob, json, os, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = sorted(glob.glob(os.path.join(ROOT, 'Incoming', 'Flows', 'SiteManagement-Exportfile_*.zip')))[-1]
OUT_ZIP = os.path.join(ROOT, 'artifacts', 'flows', 'SiteManagement-Import-rows-v2.zip')
OUT_DEF = os.path.join(ROOT, 'flows', 'SiteManagement-Import-rows.definition.json')
NAME = 'SiteManagement - Import rows'
SITE = 'https://geacloud.sharepoint.com/sites/GEASiteManagment'
SITE_REL = '/sites/GEASiteManagment'
LIB = 'Imports'
ALLOWED = ['Translations', 'AppSettings', 'Customers', 'ProjectSafety']
SP = '/providers/Microsoft.PowerApps/apis/shared_sharepointonline'
AUTH = "@parameters('$authentication')"
RETRY = {'type': 'fixed', 'count': 2, 'interval': 'PT5S'}
JSON_HDR = {'Accept': 'application/json;odata=nometadata', 'Content-Type': 'application/json;odata=nometadata'}
MAX_DEPTH = 6


def sp(op, params, run_after=None):
    return {'type': 'OpenApiConnection',
            'inputs': {'parameters': dict(params, dataset=SITE),
                       'host': {'apiId': SP, 'connectionName': 'shared_sharepointonline', 'operationId': op},
                       'retryPolicy': RETRY, 'authentication': AUTH},
            'runAfter': run_after or {}}


def http(method, uri, body=None, run_after=None):
    p = {'parameters/method': method, 'parameters/uri': uri, 'parameters/headers': JSON_HDR}
    if body is not None:
        p['parameters/body'] = body
    return sp('HttpRequest', p, run_after)


def compose(expr, run_after=None):
    return {'type': 'Compose', 'inputs': expr, 'runAfter': run_after or {}}


def query(frm, where, run_after=None):
    return {'type': 'Query', 'inputs': {'from': frm, 'where': where}, 'runAfter': run_after or {}}


def setvar(name, value, run_after=None):
    return {'type': 'SetVariable', 'inputs': {'name': name, 'value': value}, 'runAfter': run_after or {}}


def append(var, text, run_after=None):
    return {'type': 'AppendToStringVariable', 'inputs': {'name': var, 'value': text}, 'runAfter': run_after or {}}


def after(name, *states):
    return {name: list(states or ['Succeeded'])}


def chain(pairs, first_after=None):
    out, prev = {}, None
    for n, a in pairs:
        a['runAfter'] = after(prev) if prev else (first_after or {})
        out[n] = a
        prev = n
    return out


NLX = "decodeUriComponent('%0A')"
NL = "@{" + NLX + "}"
ESC = lambda e: f"replace({e}, '''', '''''')"
FIELDS = "body('Fields')"
ITEM = "items('Apply_to_each_row')"
LIST_URI = "_api/web/lists/GetByTitle('@{outputs('ListName')}')"
FORM_BODY = "@{json(concat('{\"formValues\":', string(body('Form_values')), ',\"bNewDocumentUpdate\":false}'))}"
FIRST_ID = "first(body('Get_existing')?['value'])?['Id']"

# ---- per row (inside Process > Apply_to_each_row > Row): composes, then one Switch -----------------------
row = chain([
    ('Parts', compose(f"@split({ITEM}, ';')")),
    ('Form_values', {'type': 'Select', 'inputs': {
        'from': f"@range(0, length({FIELDS}))",
        'select': {'FieldName': f"@{FIELDS}[item()]",
                   'FieldValue': f"@if(greaterOrEquals(item(), length(outputs('Parts'))), '', if(equals(item(), sub(length({FIELDS}), 1)), "
                                 f"join(skip(outputs('Parts'), item()), ';'), outputs('Parts')[item()]))"}}}),
    ('FV_title', query("@body('Form_values')", "@equals(item()?['FieldName'], 'Title')")),
    ('FV_language', query("@body('Form_values')", "@equals(item()?['FieldName'], 'Language')")),
    ('TitleVal', compose("@trim(coalesce(first(body('FV_title'))?['FieldValue'], ''))")),
    ('LangVal', compose("@if(equals(outputs('ListName'), 'Translations'), trim(coalesce(first(body('FV_language'))?['FieldValue'], '')), '')")),
    ('RowError', compose(
        f"@if(less(length(outputs('Parts')), length({FIELDS})), concat('column count ', string(length(outputs('Parts'))), ' < header'), "
        "if(or(equals(outputs('TitleVal'), ''), and(equals(outputs('ListName'), 'Translations'), equals(outputs('LangVal'), ''))), 'empty key', ''))")),
    ('KeyFilter', compose(
        "@if(equals(outputs('ListName'), 'Translations'), concat('Title eq ''', " + ESC("outputs('TitleVal')") +
        ", ''' and Language eq ''', " + ESC("outputs('LangVal')") + ", ''''), concat('Title eq ''', " + ESC("outputs('TitleVal')") + ", ''''))")),
    ('Get_existing', http('GET', LIST_URI + "/items?$select=Id&$top=10&$filter=@{encodeUriComponent(outputs('KeyFilter'))}")),
    ('Existing_count', compose("@length(coalesce(body('Get_existing')?['value'], createArray()))")),
    ('RowAction', compose(
        "@if(not(equals(outputs('RowError'), '')), 'ERROR', if(equals(outputs('Existing_count'), 0), 'ADD', "
        "if(equals(outputs('Existing_count'), 1), if(outputs('Upsert'), 'UPDATE', 'EXISTS'), 'DUPLICATE')))")),
    ('Switch_action', {
        'type': 'Switch', 'expression': "@outputs('RowAction')",
        'cases': {
            'Case_add': {'case': 'ADD', 'actions': chain([
                ('Create_item', http('POST', LIST_URI + "/AddValidateUpdateItemUsingPath", FORM_BODY)),
                ('Create_errors', query("@body('Create_item')?['value']", "@equals(item()?['HasException'], true)")),
                ('Set_result_add', setvar('RowResult',
                    "@if(greater(length(body('Create_errors')), 0), concat('ERROR;', first(body('Create_errors'))?['FieldName'], ': ', "
                    "first(body('Create_errors'))?['ErrorMessage']), concat('ADDED;id ', string(first(body('Create_item')?['value'])?['ItemId'])))")),
            ])},
            'Case_update': {'case': 'UPDATE', 'actions': chain([
                ('Update_item', http('POST', LIST_URI + "/items(@{" + FIRST_ID + "})/ValidateUpdateListItem", FORM_BODY)),
                ('Update_errors', query("@body('Update_item')?['value']", "@equals(item()?['HasException'], true)")),
                ('Set_result_update', setvar('RowResult',
                    "@if(greater(length(body('Update_errors')), 0), concat('ERROR;', first(body('Update_errors'))?['FieldName'], ': ', "
                    "first(body('Update_errors'))?['ErrorMessage']), concat('UPDATED;id ', string(" + FIRST_ID + ")))")),
            ])},
            'Case_exists': {'case': 'EXISTS', 'actions': chain([
                ('Set_result_exists', setvar('RowResult', "@concat('EXISTS;id ', string(" + FIRST_ID + "))")),
            ])},
            'Case_duplicate': {'case': 'DUPLICATE', 'actions': chain([
                ('Dup_ids', {'type': 'Select', 'inputs': {'from': "@body('Get_existing')?['value']", 'select': "@string(item()?['Id'])"}}),
                ('Set_result_duplicate', setvar('RowResult', "@concat('DUPLICATE;ids ', join(body('Dup_ids'), ' '), ' (not changed)')")),
            ])},
        },
        'default': {'actions': chain([
            ('Set_result_error', setvar('RowResult', "@concat('ERROR;', outputs('RowError'), ': ', " + ITEM + ")")),
        ])},
    }),
    ('Log_row', append('Log', "@{outputs('TitleVal')};@{outputs('LangVal')};@{variables('RowResult')}" + NL)),
])

loop = {
    'type': 'Foreach', 'foreach': "@if(outputs('HeaderOK'), body('Rows'), createArray())",
    'actions': {
        'Row': {'type': 'Scope', 'actions': row, 'runAfter': {}},
        'Log_row_failed': append('Log', f"-;-;ERROR;request failed (see run history): @{{{ITEM}}}" + NL, after('Row', 'Failed', 'TimedOut')),
    },
    'runtimeConfiguration': {'concurrency': {'repetitions': 1}},
}

process = chain([
    ('Wait_for_upload', {'type': 'Wait', 'inputs': {'interval': {'count': 15, 'unit': 'Second'}}}),
    ('Get_file_content', sp('GetFileContentByPath', {'path': "/@{outputs('FullPath')}", 'inferContentType': False})),
    ('Text', compose("@replace(replace(base64ToString(body('Get_file_content')?['$content']), decodeUriComponent('%EF%BB%BF'), ''), decodeUriComponent('%0D'), '')")),
    ('Lines', compose(f"@split(outputs('Text'), {NLX})")),
    ('Fields', {'type': 'Select', 'inputs': {'from': "@split(first(outputs('Lines')), ';')",
                                             'select': "@if(equals(trim(item()), 'Key'), 'Title', trim(item()))"}}),
    ('Rows', query("@skip(outputs('Lines'), 1)", "@not(equals(trim(item()), ''))")),
    ('HeaderOK', compose(
        "@and(contains(createArray(" + ", ".join(f"'{x}'" for x in ALLOWED) + "), outputs('ListName')), contains(body('Fields'), 'Title'), "
        "or(not(equals(outputs('ListName'), 'Translations')), contains(body('Fields'), 'Language')))")),
    ('Log_header', append('Log', "@{if(outputs('HeaderOK'), '', concat('-;-;ERROR;list not allowed or header without Title (Translations: Key/Title + Language): ', "
                                 "first(outputs('Lines')), " + NLX + "))}")),
    ('Apply_to_each_row', loop),
])

# counters derived from the log (no counters inside branches)
LOGLINES = f"split(variables('Log'), {NLX})"
count = lambda tag: query(f"@{LOGLINES}", f"@contains(item(), ';{tag};')")
result_body = ("@{concat(decodeUriComponent('%EF%BB%BF'), 'Summary;List=', outputs('ListName'), ';File=', outputs('FileName'), ';Mode=', "
               "if(outputs('Upsert'), 'upsert', 'add-only'), ';Rows=', string(length(body('Rows'))), "
               "';Added=', string(length(body('Count_added'))), ';Updated=', string(length(body('Count_updated'))), "
               "';Exists=', string(length(body('Count_exists'))), ';Duplicates=', string(length(body('Count_duplicate'))), "
               f"';Errors=', string(length(body('Count_error'))), {NLX}, 'Key;Language;Result;Detail', {NLX}, variables('Log'))}}")
ESC_PATH = lambda e: "@{" + ESC(e) + "}"

actions = chain(
    [(f'Init_{v}', {'type': 'InitializeVariable', 'inputs': {'variables': [{'name': v, 'type': 'string', 'value': ''}]}}) for v in ('Log', 'RowResult')] + [
        ('FullPath', compose("@triggerOutputs()?['body/{FullPath}']")),
        ('FileName', compose("@triggerOutputs()?['body/{FilenameWithExtension}']")),
        ('PathParts', query("@split(coalesce(triggerOutputs()?['body/{Path}'], ''), '/')", "@not(equals(item(), ''))")),
        ('ListName', compose("@if(equals(length(body('PathParts')), 2), last(body('PathParts')), '')")),
        ('Upsert', compose("@startsWith(toLower(outputs('FileName')), 'upsert_')")),
        ('Stamp', compose("@{utcNow('yyyyMMdd_HHmmss')}")),
        ('Check_ignore', {
            'type': 'If',
            'expression': {'not': {'and': [
                {'equals': ["@length(body('PathParts'))", 2]},
                {'equals': ["@first(body('PathParts'))", LIB]},
                {'not': {'equals': ["@outputs('ListName')", 'Done']}},
                {'endsWith': ["@toLower(outputs('FileName'))", '.csv']},
            ]}},
            'actions': {'Ignore': {'type': 'Terminate', 'inputs': {'runStatus': 'Succeeded'}, 'runAfter': {}}},
            'else': {'actions': {}},
        }),
        ('Process', {'type': 'Scope', 'actions': process}),
    ])
tail = chain([
    ('Count_added', count('ADDED')),
    ('Count_updated', count('UPDATED')),
    ('Count_exists', count('EXISTS')),
    ('Count_duplicate', count('DUPLICATE')),
    ('Count_error', count('ERROR')),
    ('Write_result', sp('CreateFile', {'folderPath': f'/{LIB}/Done', 'name': "@{outputs('Stamp')}_@{outputs('FileName')}.result.csv", 'body': result_body})),
    ('Move_to_Done', http('POST', f"_api/web/GetFileByServerRelativeUrl('{SITE_REL}/" + ESC_PATH("outputs('FullPath')") +
                          f"')/moveto(newurl='{SITE_REL}/{LIB}/Done/" + ESC_PATH("concat(outputs('Stamp'), '_', outputs('FileName'))") + "',flags=1)")),
], after('Process', 'Succeeded', 'Failed', 'TimedOut'))
actions.update(tail)

trigger = {'When_a_file_is_created_in_Imports': {
    'type': 'OpenApiConnection',
    'inputs': {'parameters': {'dataset': SITE, 'table': LIB},
               'host': {'apiId': SP, 'connectionName': 'shared_sharepointonline', 'operationId': 'GetOnNewFileItems'},
               'authentication': AUTH},
    'recurrence': {'interval': 1, 'frequency': 'Minute'},
    'splitOn': "@triggerOutputs()?['body/value']",
}}


def depth(acts, level=0):
    """Max nesting level of actions (top-level actions = level 0, like Power Automate's error message)."""
    m = level
    for a in acts.values():
        subs = [a.get('actions') or {}, (a.get('else') or {}).get('actions') or {}, (a.get('default') or {}).get('actions') or {}]
        subs += [c.get('actions') or {} for c in (a.get('cases') or {}).values()]
        for s in subs:
            if s:
                m = max(m, depth(s, level + 1))
    return m


def main_build():
    with zipfile.ZipFile(BASE) as z:
        names = z.namelist()
        files = {n: z.read(n) for n in names}
    def_name = [n for n in names if n.endswith('/definition.json')][0]
    d = json.loads(files[def_name].decode('utf-8-sig'))
    p = d['properties']
    p['displayName'] = NAME
    p['definition']['triggers'] = trigger
    p['definition']['actions'] = actions
    p['connectionReferences'] = {k: dict(v, source='Embedded') for k, v in p['connectionReferences'].items() if k == 'shared_sharepointonline'}
    dmax = depth(actions)
    assert dmax <= MAX_DEPTH, f'nesting {dmax} > {MAX_DEPTH}'
    files[def_name] = json.dumps(d, ensure_ascii=False).encode('utf-8')
    # drop the OneDrive connection from manifest and maps
    flow_dir = def_name.rsplit('/', 1)[0]
    apis = json.loads(files[flow_dir + '/apisMap.json'].decode('utf-8-sig'))
    conns = json.loads(files[flow_dir + '/connectionsMap.json'].decode('utf-8-sig'))
    drop = {apis.pop('shared_onedriveforbusiness', None), conns.pop('shared_onedriveforbusiness', None)} - {None}
    files[flow_dir + '/apisMap.json'] = json.dumps(apis).encode('utf-8')
    files[flow_dir + '/connectionsMap.json'] = json.dumps(conns).encode('utf-8')
    man = json.loads(files['manifest.json'].decode('utf-8-sig'))
    man['details']['displayName'] = NAME
    for rid in drop:
        man['resources'].pop(rid, None)
    for r in man['resources'].values():
        r['dependsOn'] = [x for x in r.get('dependsOn', []) if x not in drop]
        if r.get('type') == 'Microsoft.Flow/flows':
            r['details']['displayName'] = NAME
            r['suggestedCreationType'] = 'New'
    files['manifest.json'] = json.dumps(man, ensure_ascii=False).encode('utf-8')
    os.makedirs(os.path.dirname(OUT_ZIP), exist_ok=True)
    with zipfile.ZipFile(OUT_ZIP, 'w', zipfile.ZIP_DEFLATED) as z:
        for n in names:
            z.writestr(n, files[n])
    s = copy.deepcopy(d)  # sanitized copy for git: no creator/tenant/connection ids
    s.pop('name', None); s.pop('id', None)
    s['properties']['definition'].pop('metadata', None)
    for ref in s['properties']['connectionReferences'].values():
        ref.pop('connectionName', None)
    with open(OUT_DEF, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(s, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('base', os.path.basename(BASE)); print('nesting', dmax); print('dropped', sorted(drop)); print('zip', OUT_ZIP)


if __name__ == '__main__':
    main_build()
