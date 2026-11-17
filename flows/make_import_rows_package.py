# Builds the import package "SiteManagement - Import rows" (route 2 of the import working method, Eddy 17-11-2026).
# Base = Eddy's latest export of "SiteManagement - Export file" (Incoming/Flows, gitignored): same SharePoint connection.
# Changed: definition.json (new flow) and the display name in the manifests (so Import Package cannot be mistaken
# for an update of the Export flow; Eddy imports with "Create as new").
# Output: artifacts/flows/SiteManagement-Import-rows-v1.zip (gitignored) + sanitized flows/SiteManagement-Import-rows.definition.json.
# Run from the repo root: py -E -P flows/make_import_rows_package.py
import copy, glob, json, os, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = sorted(glob.glob(os.path.join(ROOT, 'Incoming', 'Flows', 'SiteManagement-Exportfile_*.zip')))[-1]
OUT_ZIP = os.path.join(ROOT, 'artifacts', 'flows', 'SiteManagement-Import-rows-v1.zip')
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


def sp(op, params, run_after=None):
    a = {'type': 'OpenApiConnection',
         'inputs': {'parameters': dict(params, dataset=SITE),
                    'host': {'apiId': SP, 'connectionName': 'shared_sharepointonline', 'operationId': op},
                    'retryPolicy': RETRY, 'authentication': AUTH},
         'runAfter': run_after or {}}
    return a


def http(method, uri, body=None, run_after=None):
    p = {'parameters/method': method, 'parameters/uri': uri, 'parameters/headers': JSON_HDR}
    if body is not None:
        p['parameters/body'] = body
    return sp('HttpRequest', p, run_after)


def compose(expr, run_after=None):
    return {'type': 'Compose', 'inputs': expr, 'runAfter': run_after or {}}


def after(name, *states):
    return {name: list(states or ['Succeeded'])}


def append(var, text, run_after=None):
    return {'type': 'AppendToStringVariable', 'inputs': {'name': var, 'value': text}, 'runAfter': run_after or {}}


def incr(var, run_after=None):
    return {'type': 'IncrementVariable', 'inputs': {'name': var, 'value': 1}, 'runAfter': run_after or {}}


NL = "@{decodeUriComponent('%0A')}"
ESC = lambda e: f"replace({e}, '''', '''''')"
KEYLOG = "@{outputs('TitleVal')};@{outputs('LangVal')}"

# ---- per row --------------------------------------------------------------------------------------------
fields = "body('Fields')"
row = {
    'Parts': compose("@split(items('Apply_to_each_row'), ';')"),
    'Check_columns': {
        'type': 'If',
        'expression': {'less': ["@length(outputs('Parts'))", f"@length({fields})"]},
        'actions': {
            'Err_columns_count': incr('Errors'),
            'Log_columns': append('Log', "-;-;ERROR;column count " + "@{length(outputs('Parts'))}" + " < header: @{items('Apply_to_each_row')}" + NL,
                                  after('Err_columns_count')),
        },
        'else': {'actions': {
            'Form_values': {
                'type': 'Select',
                'inputs': {'from': f"@range(0, length({fields}))",
                           'select': {'FieldName': f"@{fields}[item()]",
                                      'FieldValue': f"@if(equals(item(), sub(length({fields}), 1)), join(skip(outputs('Parts'), item()), ';'), outputs('Parts')[item()])"}},
                'runAfter': {}},
            'FV_title': {'type': 'Query', 'inputs': {'from': "@body('Form_values')", 'where': "@equals(item()?['FieldName'], 'Title')"},
                         'runAfter': after('Form_values')},
            'FV_language': {'type': 'Query', 'inputs': {'from': "@body('Form_values')", 'where': "@equals(item()?['FieldName'], 'Language')"},
                            'runAfter': after('FV_title')},
            'TitleVal': compose("@trim(coalesce(first(body('FV_title'))?['FieldValue'], ''))", after('FV_language')),
            'LangVal': compose("@if(equals(outputs('ListName'), 'Translations'), trim(coalesce(first(body('FV_language'))?['FieldValue'], '')), '')", after('TitleVal')),
            'KeyFilter': compose(
                "@if(equals(outputs('ListName'), 'Translations'), concat('Title eq ''', " + ESC("outputs('TitleVal')") +
                ", ''' and Language eq ''', " + ESC("outputs('LangVal')") + ", ''''), concat('Title eq ''', " + ESC("outputs('TitleVal')") + ", ''''))",
                after('LangVal')),
            'Check_key': {
                'type': 'If',
                'expression': {'or': [{'equals': ["@outputs('TitleVal')", '']},
                                      {'and': [{'equals': ["@outputs('ListName')", 'Translations']}, {'equals': ["@outputs('LangVal')", '']}]}]},
                'actions': {
                    'Err_key': incr('Errors'),
                    'Log_key': append('Log', KEYLOG + ";ERROR;empty key" + NL, after('Err_key')),
                },
                'else': {'actions': {
                    'Get_existing': http('GET', "_api/web/lists/GetByTitle('@{outputs('ListName')}')/items?$select=Id&$top=10&$filter=@{encodeUriComponent(outputs('KeyFilter'))}"),
                    'Existing_count': compose("@length(body('Get_existing')?['value'])", after('Get_existing')),
                    'Switch_existing': {
                        'type': 'Switch', 'expression': "@if(greater(outputs('Existing_count'), 1), 'many', string(outputs('Existing_count')))",
                        'cases': {
                            'Case_new': {'case': '0', 'actions': {
                                'Create_item': http('POST', "_api/web/lists/GetByTitle('@{outputs('ListName')}')/AddValidateUpdateItemUsingPath",
                                                    "@{json(concat('{\"formValues\":', string(body('Form_values')), ',\"bNewDocumentUpdate\":false}'))}"),
                                'Create_errors': {'type': 'Query', 'inputs': {'from': "@body('Create_item')?['value']", 'where': "@equals(item()?['HasException'], true)"},
                                                  'runAfter': after('Create_item')},
                                'Check_create': {
                                    'type': 'If', 'expression': {'greater': ["@length(body('Create_errors'))", 0]},
                                    'actions': {
                                        'Err_create': incr('Errors'),
                                        'Log_create_err': append('Log', KEYLOG + ";ERROR;@{first(body('Create_errors'))?['FieldName']}: @{first(body('Create_errors'))?['ErrorMessage']}" + NL, after('Err_create')),
                                    },
                                    'else': {'actions': {
                                        'Count_added': incr('Added'),
                                        'Log_added': append('Log', KEYLOG + ";ADDED;id @{first(body('Create_item')?['value'])?['ItemId']}" + NL, after('Count_added')),
                                    }},
                                    'runAfter': after('Create_errors')},
                            }},
                            'Case_one': {'case': '1', 'actions': {
                                'Check_mode': {
                                    'type': 'If', 'expression': {'equals': ["@outputs('Upsert')", True]},
                                    'actions': {
                                        'Update_item': http('POST', "_api/web/lists/GetByTitle('@{outputs('ListName')}')/items(@{first(body('Get_existing')?['value'])?['Id']})/ValidateUpdateListItem",
                                                            "@{json(concat('{\"formValues\":', string(body('Form_values')), ',\"bNewDocumentUpdate\":false}'))}"),
                                        'Update_errors': {'type': 'Query', 'inputs': {'from': "@body('Update_item')?['value']", 'where': "@equals(item()?['HasException'], true)"},
                                                          'runAfter': after('Update_item')},
                                        'Check_update': {
                                            'type': 'If', 'expression': {'greater': ["@length(body('Update_errors'))", 0]},
                                            'actions': {
                                                'Err_update': incr('Errors'),
                                                'Log_update_err': append('Log', KEYLOG + ";ERROR;@{first(body('Update_errors'))?['FieldName']}: @{first(body('Update_errors'))?['ErrorMessage']}" + NL, after('Err_update')),
                                            },
                                            'else': {'actions': {
                                                'Count_updated': incr('Updated'),
                                                'Log_updated': append('Log', KEYLOG + ";UPDATED;id @{first(body('Get_existing')?['value'])?['Id']}" + NL, after('Count_updated')),
                                            }},
                                            'runAfter': after('Update_errors')},
                                    },
                                    'else': {'actions': {
                                        'Count_exists': incr('Exists'),
                                        'Log_exists': append('Log', KEYLOG + ";EXISTS;id @{first(body('Get_existing')?['value'])?['Id']}" + NL, after('Count_exists')),
                                    }},
                                    'runAfter': {}},
                            }},
                        },
                        'default': {'actions': {
                            'Dup_ids': {'type': 'Select', 'inputs': {'from': "@body('Get_existing')?['value']", 'select': "@string(item()?['Id'])"}, 'runAfter': {}},
                            'Count_duplicate': incr('Duplicates', after('Dup_ids')),
                            'Log_duplicate': append('Log', KEYLOG + ";DUPLICATE;ids @{join(body('Dup_ids'), ' ')} (not changed)" + NL, after('Count_duplicate')),
                        }},
                        'runAfter': after('Existing_count')},
                }},
                'runAfter': after('KeyFilter')},
        }},
        'runAfter': after('Parts')},
}

loop = {
    'type': 'Foreach', 'foreach': "@body('Rows')",
    'actions': {
        'Row': {'type': 'Scope', 'actions': row, 'runAfter': {}},
        'Row_failed': {'type': 'Scope', 'actions': {
            'Count_row_error': incr('Errors'),
            'Log_row_error': append('Log', "-;-;ERROR;request failed (see run history): @{items('Apply_to_each_row')}" + NL, after('Count_row_error')),
        }, 'runAfter': after('Row', 'Failed', 'TimedOut')},
    },
    'runtimeConfiguration': {'concurrency': {'repetitions': 1}},
    'runAfter': {},
}

process = {
    'Wait_for_upload': {'type': 'Wait', 'inputs': {'interval': {'count': 15, 'unit': 'Second'}}, 'runAfter': {}},
    'Get_file_content': sp('GetFileContentByPath', {'path': "/@{outputs('FullPath')}", 'inferContentType': False}, after('Wait_for_upload')),
    'Text': compose("@replace(replace(base64ToString(body('Get_file_content')?['$content']), decodeUriComponent('%EF%BB%BF'), ''), decodeUriComponent('%0D'), '')",
                    after('Get_file_content')),
    'Lines': compose("@split(outputs('Text'), decodeUriComponent('%0A'))", after('Text')),
    'Fields': {'type': 'Select', 'inputs': {'from': "@split(first(outputs('Lines')), ';')",
                                            'select': "@if(equals(trim(item()), 'Key'), 'Title', trim(item()))"},
               'runAfter': after('Lines')},
    'Rows': {'type': 'Query', 'inputs': {'from': "@skip(outputs('Lines'), 1)", 'where': "@not(equals(trim(item()), ''))"},
             'runAfter': after('Fields')},
    'Check_header': {
        'type': 'If',
        'expression': {'and': [
            {'contains': ["@createArray(" + ", ".join(f"'{x}'" for x in ALLOWED) + ")", "@outputs('ListName')"]},
            {'contains': ["@body('Fields')", 'Title']},
            {'or': [{'not': {'equals': ["@outputs('ListName')", 'Translations']}}, {'contains': ["@body('Fields')", 'Language']}]},
        ]},
        'actions': {'Apply_to_each_row': loop},
        'else': {'actions': {
            'Count_header_error': incr('Errors'),
            'Log_header': append('Log', "-;-;ERROR;list not allowed or header without Title (Translations: Key/Title + Language): @{first(outputs('Lines'))}" + NL,
                                 after('Count_header_error')),
        }},
        'runAfter': after('Rows')},
}

result_body = ("@{concat(decodeUriComponent('%EF%BB%BF'), 'Summary;List=', outputs('ListName'), ';File=', outputs('FileName'), ';Mode=', "
               "if(outputs('Upsert'), 'upsert', 'add-only'), ';Rows=', string(length(body('Rows'))), ';Added=', string(variables('Added')), "
               "';Updated=', string(variables('Updated')), ';Exists=', string(variables('Exists')), ';Duplicates=', string(variables('Duplicates')), "
               "';Errors=', string(variables('Errors')), decodeUriComponent('%0A'), 'Key;Language;Result;Detail', decodeUriComponent('%0A'), variables('Log'))}")

done_name = "@{outputs('Stamp')}_@{outputs('FileName')}"
main = {
    'Write_result': sp('CreateFile', {'folderPath': f'/{LIB}/Done', 'name': "@{outputs('Stamp')}_@{outputs('FileName')}.result.csv", 'body': result_body},
                       after('Process', 'Succeeded', 'Failed', 'TimedOut')),
    'Move_to_Done': http('POST', f"_api/web/GetFileByServerRelativeUrl('{SITE_REL}/@{{" + ESC("outputs('FullPath')") + "}')/moveto(newurl='" + SITE_REL + f"/{LIB}/Done/@{{" + ESC("concat(outputs('Stamp'), '_', outputs('FileName'))") + "}',flags=1)",
                         None, after('Write_result', 'Succeeded', 'Failed')),
}

actions = {}
prev = None
for v, t, val in [('Log', 'string', ''), ('Added', 'integer', 0), ('Updated', 'integer', 0), ('Exists', 'integer', 0),
                  ('Duplicates', 'integer', 0), ('Errors', 'integer', 0)]:
    n = f'Init_{v}'
    actions[n] = {'type': 'InitializeVariable', 'inputs': {'variables': [{'name': v, 'type': t, 'value': val}]},
                  'runAfter': after(prev) if prev else {}}
    prev = n
seq = [
    ('FullPath', compose("@triggerOutputs()?['body/{FullPath}']")),
    ('FileName', compose("@triggerOutputs()?['body/{FilenameWithExtension}']")),
    ('PathParts', {'type': 'Query', 'inputs': {'from': "@split(coalesce(triggerOutputs()?['body/{Path}'], ''), '/')", 'where': "@not(equals(item(), ''))"}}),
    ('ListName', compose("@if(equals(length(body('PathParts')), 2), last(body('PathParts')), '')")),
    ('Upsert', compose("@startsWith(toLower(outputs('FileName')), 'upsert_')")),
    ('Stamp', compose("@{utcNow('yyyyMMdd_HHmmss')}")),
]
for n, a in seq:
    a['runAfter'] = after(prev)
    actions[n] = a
    prev = n
actions['Check_file'] = {
    'type': 'If',
    'expression': {'and': [
        {'equals': ["@length(body('PathParts'))", 2]},
        {'equals': ["@first(body('PathParts'))", LIB]},
        {'not': {'equals': ["@outputs('ListName')", 'Done']}},
        {'endsWith': ["@toLower(outputs('FileName'))", '.csv']},
    ]},
    'actions': dict({'Process': {'type': 'Scope', 'actions': process, 'runAfter': {}}}, **main),
    'else': {'actions': {'Ignore': {'type': 'Terminate', 'inputs': {'runStatus': 'Succeeded'}, 'runAfter': {}}}},
    'runAfter': after(prev),
}

trigger = {'When_a_file_is_created_in_Imports': {
    'type': 'OpenApiConnection',
    'inputs': {'parameters': {'dataset': SITE, 'table': LIB},
               'host': {'apiId': SP, 'connectionName': 'shared_sharepointonline', 'operationId': 'GetOnNewFileItems'},
               'authentication': AUTH},
    'recurrence': {'interval': 1, 'frequency': 'Minute'},
    'splitOn': "@triggerOutputs()?['body/value']",
}}


def main_build():
    with zipfile.ZipFile(BASE) as z:
        names = z.namelist()
        files = {n: z.read(n) for n in names}
    def_name = [n for n in names if n.endswith('/definition.json')][0]
    base_def = json.loads(files[def_name].decode('utf-8-sig'))
    d = copy.deepcopy(base_def)
    p = d['properties']
    p['displayName'] = NAME
    df = p['definition']
    df['triggers'] = trigger
    df['actions'] = actions
    for ref in p['connectionReferences'].values():
        ref['source'] = 'Embedded'
    files[def_name] = json.dumps(d, ensure_ascii=False).encode('utf-8')
    man = json.loads(files['manifest.json'].decode('utf-8-sig'))
    man['details']['displayName'] = NAME
    for r in man['resources'].values():
        if r.get('type') == 'Microsoft.Flow/flows':
            r['details']['displayName'] = NAME
            r['suggestedCreationType'] = 'New'
    files['manifest.json'] = json.dumps(man, ensure_ascii=False).encode('utf-8')
    os.makedirs(os.path.dirname(OUT_ZIP), exist_ok=True)
    with zipfile.ZipFile(OUT_ZIP, 'w', zipfile.ZIP_DEFLATED) as z:
        for n in names:
            z.writestr(n, files[n])
    # sanitized copy for git: no creator/tenant/connection ids
    s = copy.deepcopy(d)
    s.pop('name', None); s.pop('id', None)
    s['properties']['definition'].pop('metadata', None)
    for ref in s['properties']['connectionReferences'].values():
        ref.pop('connectionName', None)
    with open(OUT_DEF, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(s, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('base', os.path.basename(BASE)); print('zip', OUT_ZIP); print('def', OUT_DEF)


if __name__ == '__main__':
    main_build()
