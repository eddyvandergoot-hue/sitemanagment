# Builds the import package "SiteManagement - Mail draft" (Eddy 19-11-2026, v1.0.2: Week Report button Mail).
# One call per contractor: the app passes Folder (Exports/<Folder>), FileNames ("|"-separated, the files of ONE contractor
# from the last successful export), Subject and Body (plain text). The flow reads each file from the Exports library and
# creates an Outlook DRAFT in the mailbox of the app user (Invoker connection) WITHOUT recipients, with the files attached.
# It never sends mail. Output: Status (OK | Error), WebLink (Outlook web link of the draft), Message.
# Route (Eddy 19-11-2026): Office 365 Outlook "Send an HTTP request" (operationId HttpRequest, standard connector) with
# Microsoft Graph POST /me/messages, because "Draft an email message" (DraftEmail) requires To and returns no web link.
# Base = Eddy's latest export of "SiteManagement - Export file" (Incoming/Flows, gitignored): same SharePoint connection;
# its unused OneDrive connection slot becomes the Office 365 Outlook connection (Eddy picks the connection at import).
# Nesting <= 6 (artifacts/Test-FlowNesting.ps1). Graph limit: one request <= 4 MB (week report PDFs + CSV are far smaller).
# Output: artifacts/flows/SiteManagement-Mail-draft-v1.zip (gitignored) + sanitized flows/SiteManagement-Mail-draft.definition.json.
# Run from the repo root: py -E -P flows/make_mail_draft_package.py
import copy, glob, json, os, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = sorted(glob.glob(os.path.join(ROOT, 'Incoming', 'Flows', 'SiteManagement-Exportfile_*.zip')))[-1]
OUT_ZIP = os.path.join(ROOT, 'artifacts', 'flows', 'SiteManagement-Mail-draft-v1.zip')
OUT_DEF = os.path.join(ROOT, 'flows', 'SiteManagement-Mail-draft.definition.json')
NAME = 'SiteManagement - Mail draft'
SITE = 'https://geacloud.sharepoint.com/sites/GEASiteManagment'
SP = '/providers/Microsoft.PowerApps/apis/shared_sharepointonline'
OL = '/providers/Microsoft.PowerApps/apis/shared_office365'
AUTH = {'value': "@json(decodeBase64(triggerOutputs().headers['X-MS-APIM-Tokens']))['$ConnectionKey']", 'type': 'Raw'}
RETRY = {'type': 'fixed', 'count': 2, 'interval': 'PT5S'}
MAX_DEPTH = 6
MAX_FILES = 10


def text_input(title):
    return {'description': 'Please enter your input', 'title': title, 'type': 'string',
            'x-ms-content-hint': 'TEXT', 'x-ms-dynamically-added': True}


trigger = {'manual': {'type': 'Request', 'kind': 'PowerAppV2', 'inputs': {'schema': {
    'type': 'object',
    'properties': {'text': text_input('Folder'), 'text_1': text_input('FileNames'),
                   'text_2': text_input('Subject'), 'text_3': text_input('Body')},
    'required': ['text', 'text_1', 'text_2', 'text_3']}}}}

FOLDER = "triggerBody()?['text']"
NAMES = "body('File_names')"


def respond(status, weblink, message, run_after):
    return {'runAfter': run_after, 'type': 'Response', 'kind': 'PowerApp', 'inputs': {
        'schema': {'type': 'object', 'properties': {
            'status': {'title': 'Status', 'type': 'string', 'x-ms-content-hint': 'TEXT', 'x-ms-dynamically-added': True},
            'weblink': {'title': 'WebLink', 'type': 'string', 'x-ms-content-hint': 'TEXT', 'x-ms-dynamically-added': True},
            'message': {'title': 'Message', 'type': 'string', 'x-ms-content-hint': 'TEXT', 'x-ms-dynamically-added': True}},
            'additionalProperties': {}},
        'statusCode': 200, 'body': {'status': status, 'weblink': weblink, 'message': message}}}


per_file = {
    'Get_file_content': {'type': 'OpenApiConnection', 'inputs': {
        'parameters': {'dataset': SITE, 'path': f"/Exports/@{{{FOLDER}}}/@{{items('For_each_file')}}", 'inferContentType': False},
        'host': {'apiId': SP, 'connectionName': 'shared_sharepointonline', 'operationId': 'GetFileContentByPath'},
        'authentication': AUTH, 'retryPolicy': RETRY}, 'runAfter': {}},
    'Add_attachment': {'type': 'AppendToArrayVariable', 'inputs': {'name': 'Attachments', 'value': {
        '@odata.type': '#microsoft.graph.fileAttachment',
        'name': "@{items('For_each_file')}",
        'contentBytes': "@{body('Get_file_content')?['$content']}"}},
        'runAfter': {'Get_file_content': ['Succeeded']}},
}

try_actions = {
    'File_names': {'type': 'Query', 'inputs': {'from': "@split(triggerBody()?['text_1'], '|')",
                                               'where': "@not(equals(trim(item()), ''))"}, 'runAfter': {}},
    'Check_input': {'type': 'If', 'runAfter': {'File_names': ['Succeeded']},
                    'expression': {'or': [{'equals': [f"@length({NAMES})", 0]},
                                          {'greater': [f"@length({NAMES})", MAX_FILES]},
                                          {'equals': [f"@trim(coalesce({FOLDER}, ''))", '']},
                                          {'contains': [f"@{FOLDER}", '/']},
                                          {'contains': [f"@triggerBody()?['text_1']", '/']}]},
                    'actions': {'Respond_bad_input': respond('Error', '', f'Bad input: 1-{MAX_FILES} file names and one folder name (no /) needed. Nothing created.', {}),
                                'Stop_bad_input': {'type': 'Terminate', 'inputs': {'runStatus': 'Succeeded'},
                                                   'runAfter': {'Respond_bad_input': ['Succeeded']}}},
                    'else': {'actions': {}}},
    'For_each_file': {'type': 'Foreach', 'foreach': f"@{NAMES}", 'actions': per_file,
                      'runAfter': {'Check_input': ['Succeeded']},
                      'runtimeConfiguration': {'concurrency': {'repetitions': 1}}},
    'Draft_body': {'type': 'Compose', 'runAfter': {'For_each_file': ['Succeeded']}, 'inputs': {
        'subject': "@{triggerBody()?['text_2']}",
        'body': {'contentType': 'Text', 'content': "@{triggerBody()?['text_3']}"},
        'attachments': "@variables('Attachments')"}},
    'Create_draft': {'type': 'OpenApiConnection', 'runAfter': {'Draft_body': ['Succeeded']}, 'inputs': {
        'parameters': {'Uri': 'https://graph.microsoft.com/v1.0/me/messages', 'Method': 'POST',
                       'Body': "@{string(outputs('Draft_body'))}", 'ContentType': 'application/json'},
        'host': {'apiId': OL, 'connectionName': 'shared_office365', 'operationId': 'HttpRequest'},
        'authentication': AUTH, 'retryPolicy': {'type': 'none'}}},  # a retried POST could create a second draft
    'Respond_OK': respond('OK', "@{coalesce(body('Create_draft')?['webLink'], '')}",
                          "@{concat('Draft created with ', string(length(variables('Attachments'))), ' attachment(s)')}",
                          {'Create_draft': ['Succeeded']}),
}

actions = {
    'Init_attachments': {'type': 'InitializeVariable', 'inputs': {'variables': [{'name': 'Attachments', 'type': 'array', 'value': []}]},
                         'runAfter': {}},
    'Try': {'type': 'Scope', 'actions': try_actions, 'runAfter': {'Init_attachments': ['Succeeded']}},
    'Failed_steps': {'type': 'Query', 'runAfter': {'Try': ['Failed', 'TimedOut']},
                     'inputs': {'from': "@result('Try')", 'where': "@equals(item()?['status'], 'Failed')"}},
    'Respond_error': respond('Error', '',
                             "@{concat('No draft created. Failed step: ', coalesce(first(body('Failed_steps'))?['name'], 'unknown'), "
                             "if(equals(coalesce(first(body('Failed_steps'))?['name'], ''), 'For_each_file'), ' (a file is missing in Exports: export again)', ''), "
                             "'. See the flow run history.')}",
                             {'Failed_steps': ['Succeeded', 'Failed']}),
}


def depth(acts, level=0):
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
    refs = p['connectionReferences']
    od = refs.pop('shared_onedriveforbusiness')
    refs['shared_office365'] = dict(od, id=OL, apiName='office365')
    p['connectionReferences'] = {k: refs[k] for k in ('shared_sharepointonline', 'shared_office365')}
    dmax = depth(actions)
    assert dmax <= MAX_DEPTH, f'nesting {dmax} > {MAX_DEPTH}'
    files[def_name] = json.dumps(d, ensure_ascii=False).encode('utf-8')
    # the OneDrive slot becomes the Office 365 Outlook connection (same resource ids, new api)
    flow_dir = def_name.rsplit('/', 1)[0]
    apis = json.loads(files[flow_dir + '/apisMap.json'].decode('utf-8-sig'))
    conns = json.loads(files[flow_dir + '/connectionsMap.json'].decode('utf-8-sig'))
    api_rid = apis.pop('shared_onedriveforbusiness'); con_rid = conns.pop('shared_onedriveforbusiness')
    apis['shared_office365'] = api_rid; conns['shared_office365'] = con_rid
    files[flow_dir + '/apisMap.json'] = json.dumps(apis).encode('utf-8')
    files[flow_dir + '/connectionsMap.json'] = json.dumps(conns).encode('utf-8')
    man = json.loads(files['manifest.json'].decode('utf-8-sig'))
    man['details']['displayName'] = NAME
    icon = 'https://static.powerapps.com/resource/ppcr/releases/v1.0.1827/1.0.1827.4902/office365/icon.png'  # display only
    r = man['resources'][api_rid]
    r['id'] = OL; r['name'] = 'shared_office365'; r['details'] = {'displayName': 'Office 365 Outlook', 'iconUri': icon}
    man['resources'][con_rid]['details']['iconUri'] = icon
    man['resources'][con_rid]['details']['displayName'] = 'Office 365 Outlook'
    for r in man['resources'].values():
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
    print('base', os.path.basename(BASE)); print('nesting', dmax); print('zip', OUT_ZIP)


if __name__ == '__main__':
    main_build()
