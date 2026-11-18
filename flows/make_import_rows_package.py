# Builds the import package "SiteManagement - Import rows" (route 2 of the import working method, Eddy 17-11-2026).
# Base = Eddy's latest export of "SiteManagement - Export file" (Incoming/Flows, gitignored): same SharePoint connection.
# Changed vs base: definition.json (new flow), display name in the manifests, OneDrive connection removed (unused).
# v3 (18-11-2026, v1.0.1): existing rows read once per file (no read per row), ~4 actions per row, 10 rows in parallel,
# duplicate keys in the file block the whole file (fail-closed), lists above 5000 rows are refused.
# v2 (17-11-2026): flat structure; Power Automate allows nesting level <= 8, this flow stays <= 6
# (artifacts/Test-FlowNesting.ps1). Per row: composes + one Switch; counters derived from the log after the loop.
# Output: artifacts/flows/SiteManagement-Import-rows-v3.zip (gitignored) + sanitized flows/SiteManagement-Import-rows.definition.json.
# Run from the repo root: py -E -P flows/make_import_rows_package.py
import copy, glob, json, os, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = sorted(glob.glob(os.path.join(ROOT, 'Incoming', 'Flows', 'SiteManagement-Exportfile_*.zip')))[-1]
OUT_ZIP = os.path.join(ROOT, 'artifacts', 'flows', 'SiteManagement-Import-rows-v3.zip')
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
CONCURRENCY = 10
TI = "outputs('Index_title')"
LI = "outputs('Index_language')"
PART = lambda arr, idx: f"trim(coalesce(first(skip({arr}, {idx})), ''))"  # safe index (null when out of range)
IS_TR = "equals(outputs('ListName'), 'Translations')"
P_T = PART("outputs('Parts')", TI)
P_L = PART("outputs('Parts')", LI)
INFO = "outputs('Row_info')"
MATCH = "body('Matches')"
FIRST_ID = f"string(first({MATCH})?['Id'])"


def res(expr):
    """Append one result line 'key;language;RESULT;detail' (array variable: safe with parallel iterations)."""
    return {'type': 'AppendToArrayVariable', 'inputs': {'name': 'Results', 'value': expr}}


KEYPFX = f"concat({INFO}?['Title'], ';', {INFO}?['Lang'], ';'"

# ---- per row (Process > Apply_to_each_row > Row): 4 composes/queries + one Switch with 1-2 actions --------
row = chain([
    ('Parts', compose(f"@split({ITEM}, ';')")),
    ('Form_values', {'type': 'Select', 'inputs': {
        'from': f"@range(0, length({FIELDS}))",
        'select': {'FieldName': f"@{FIELDS}[item()]",
                   'FieldValue': f"@if(equals(item(), sub(length({FIELDS}), 1)), join(skip(outputs('Parts'), item()), ';'), "
                                 f"if(or(equals({FIELDS}[item()], 'Title'), equals({FIELDS}[item()], 'Language')), trim(coalesce(first(skip(outputs('Parts'), item())), '')), coalesce(first(skip(outputs('Parts'), item())), '')))"}}}),
    ('Row_info', compose({
        'Title': f"@{P_T}",
        'Lang': f"@if({IS_TR}, {P_L}, '')",
        'Key': f"@toLower(concat({P_T}, '|', if({IS_TR}, {P_L}, '')))",
        'Error': f"@if(less(length(outputs('Parts')), length({FIELDS})), concat('column count ', string(length(outputs('Parts'))), ' < header'), "
                 f"if(or(equals({P_T}, ''), and({IS_TR}, equals({P_L}, ''))), 'empty key', ''))",
    })),
    ('Matches', query("@body('Existing')", f"@equals(item()?['K'], {INFO}?['Key'])")),
    ('Switch_action', {
        'type': 'Switch',
        'expression': f"@if(not(equals({INFO}?['Error'], '')), 'ERROR', if(equals(length({MATCH}), 0), 'ADD', "
                      f"if(equals(length({MATCH}), 1), if(outputs('Upsert'), 'UPDATE', 'EXISTS'), 'DUPLICATE')))",
        'cases': {
            'Case_add': {'case': 'ADD', 'actions': chain([
                ('Create_item', http('POST', LIST_URI + "/AddValidateUpdateItemUsingPath", FORM_BODY)),
                ('Create_errors', query("@coalesce(body('Create_item')?['value'], createArray())", "@equals(item()?['HasException'], true)")),
                ('Result_add', res(f"@{KEYPFX}, if(greater(length(body('Create_errors')), 0), "
                                   f"concat('ERROR;', first(body('Create_errors'))?['FieldName'], ': ', first(body('Create_errors'))?['ErrorMessage']), concat('ADDED;id ', string(first(body('Create_item')?['value'])?['ItemId']))))")),
            ])},
            'Case_update': {'case': 'UPDATE', 'actions': chain([
                ('Update_item', http('POST', LIST_URI + "/items(@{" + FIRST_ID + "})/ValidateUpdateListItem", FORM_BODY)),
                ('Update_errors', query("@coalesce(body('Update_item')?['value'], createArray())", "@equals(item()?['HasException'], true)")),
                ('Result_update', res(f"@{KEYPFX}, if(greater(length(body('Update_errors')), 0), "
                                      f"concat('ERROR;', first(body('Update_errors'))?['FieldName'], ': ', first(body('Update_errors'))?['ErrorMessage']), concat('UPDATED;id ', {FIRST_ID})))")),
            ])},
            'Case_exists': {'case': 'EXISTS', 'actions': chain([
                ('Result_exists', res(f"@{KEYPFX}, 'EXISTS;id ', {FIRST_ID})")),
            ])},
            'Case_duplicate': {'case': 'DUPLICATE', 'actions': chain([
                ('Result_duplicate', res(f"@{KEYPFX}, 'DUPLICATE;ids ', string({MATCH}), ' (not changed)')")),
            ])},
        },
        'default': {'actions': chain([
            ('Result_error', res(f"@{KEYPFX}, 'ERROR;', {INFO}?['Error'], ': ', {ITEM})")),
        ])},
    }),
])

loop = {
    'type': 'Foreach', 'foreach': "@if(outputs('Can_process'), body('Rows'), createArray())",
    'actions': {
        'Row': {'type': 'Scope', 'actions': row, 'runAfter': {}},
        'Result_row_failed': dict(res(f"@concat('-;-;ERROR;request failed (see run history): ', {ITEM})"), runAfter=after('Row', 'Failed', 'TimedOut')),
    },
    'runtimeConfiguration': {'concurrency': {'repetitions': CONCURRENCY}},
}

SELECT_COLS = "@{if(equals(outputs('ListName'), 'Translations'), 'Id,Title,Language', 'Id,Title')}"
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
    # real column indexes (only meaningful when HeaderOK)
    ('Field_index', {'type': 'Select', 'inputs': {'from': f"@range(0, length({FIELDS}))", 'select': {'I': "@item()", 'N': f"@{FIELDS}[item()]"}}}),
    ('Title_pos', query("@body('Field_index')", "@equals(item()?['N'], 'Title')")),
    ('Language_pos', query("@body('Field_index')", "@equals(item()?['N'], 'Language')")),
    ('Index_title', compose("@coalesce(first(body('Title_pos'))?['I'], 0)")),
    ('Index_language', compose("@coalesce(first(body('Language_pos'))?['I'], 0)")),
    # existing rows: one read of the whole list (fail-closed above 5000 = nextLink present)
    ('Get_all_existing', http('GET', LIST_URI + f"/items?$select={SELECT_COLS}&$top=5000")),
    ('Existing', {'type': 'Select', 'inputs': {'from': "@coalesce(body('Get_all_existing')?['value'], createArray())",
                                               'select': {'Id': "@item()?['Id']",
                                                          'K': f"@toLower(concat(trim(coalesce(item()?['Title'], '')), '|', if({IS_TR}, trim(coalesce(item()?['Language'], '')), '')))"}}}),
    ('File_keys', {'type': 'Select', 'inputs': {
        'from': "@if(outputs('HeaderOK'), body('Rows'), createArray())",
        'select': "@toLower(concat(" + PART("split(item(), ';')", "outputs('Index_title')") + ", '|', if(" + IS_TR + ", "
                  + PART("split(item(), ';')", "outputs('Index_language')") + ", '')))"}}),
    ('More_than_5000', compose("@or(not(empty(coalesce(body('Get_all_existing')?['odata.nextLink'], body('Get_all_existing')?['@odata.nextLink'], ''))), "
                               "greaterOrEquals(length(coalesce(body('Get_all_existing')?['value'], createArray())), 5000))")),
    ('Duplicate_keys_in_file', compose("@not(equals(length(union(body('File_keys'), body('File_keys'))), length(body('File_keys'))))")),
    ('Can_process', compose("@and(outputs('HeaderOK'), not(outputs('More_than_5000')), not(outputs('Duplicate_keys_in_file')))")),
    ('Result_header', res("@if(outputs('Can_process'), '', concat('-;-;ERROR;not processed: ', "
                          "if(not(outputs('HeaderOK')), 'list not allowed or header without Title (Translations: Key/Title + Language)', "
                          "if(outputs('More_than_5000'), 'list has more than 5000 rows', 'duplicate keys in file')), ': ', first(outputs('Lines'))))")),
    ('Apply_to_each_row', loop),
])

RESULTS = "variables('Results')"
count = lambda tag: query(f"@{RESULTS}", f"@contains(item(), ';{tag};')")
result_body = ("@{concat(decodeUriComponent('%EF%BB%BF'), 'Summary;List=', outputs('ListName'), ';File=', outputs('FileName'), ';Mode=', "
               "if(outputs('Upsert'), 'upsert', 'add-only'), ';Rows=', string(length(body('Rows'))), "
               "';Added=', string(length(body('Count_added'))), ';Updated=', string(length(body('Count_updated'))), "
               "';Exists=', string(length(body('Count_exists'))), ';Duplicates=', string(length(body('Count_duplicate'))), "
               f"';Errors=', string(length(body('Count_error'))), {NLX}, 'Key;Language;Result;Detail', {NLX}, "
               f"join(body('Result_lines'), {NLX}))}}")
ESC_PATH = lambda e: "@{" + ESC(e) + "}"

actions = chain(
    [('Init_Results', {'type': 'InitializeVariable', 'inputs': {'variables': [{'name': 'Results', 'type': 'array', 'value': []}]}})] + [
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
    ('Result_process_failed', res("@concat('-;-;ERROR;process failed (see run history): ', coalesce(outputs('FileName'), ''))")),
    ('Result_lines', dict(query(f"@{RESULTS}", "@not(equals(item(), ''))"))),
    ('Count_added', count('ADDED')),
    ('Count_updated', count('UPDATED')),
    ('Count_exists', count('EXISTS')),
    ('Count_duplicate', count('DUPLICATE')),
    ('Count_error', count('ERROR')),
    ('Write_result', sp('CreateFile', {'folderPath': f'/{LIB}/Done', 'name': "@{outputs('Stamp')}_@{outputs('FileName')}.result.csv", 'body': result_body})),
    ('Move_to_Done', http('POST', f"_api/web/GetFileByServerRelativeUrl('{SITE_REL}/" + ESC_PATH("outputs('FullPath')") +
                          f"')/moveto(newurl='{SITE_REL}/{LIB}/Done/" + ESC_PATH("concat(outputs('Stamp'), '_', outputs('FileName'))") + "',flags=1)")),
], after('Process', 'Succeeded', 'Failed', 'TimedOut'))
tail['Result_process_failed']['runAfter'] = after('Process', 'Failed', 'TimedOut')
tail['Result_lines']['runAfter'] = after('Result_process_failed', 'Succeeded', 'Skipped')
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
