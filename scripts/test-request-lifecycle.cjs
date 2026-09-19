const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');
const path = require('node:path');
const file = path.join(__dirname, '../webapp/controller/RequestWizard.controller.ts');
const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
}).outputText;
const exportsObject = {};
let hidden = 0;
vm.runInNewContext(output, {
    exports: exportsObject, setTimeout, clearTimeout, console,
    require: name => ({ default: name.endsWith('/BusyIndicator')
        ? { show() {}, hide() { hidden++; } }
        : name.endsWith('/MessageBox') ? { error() {} }
        : class {} })
});
const Controller = exportsObject.default;
function setup(success = true, respond = true) {
    const controller = new Controller();
    const state = {};
    controller._oReviewModel = { getProperty: key => state[key], setProperty: (key, value) => state[key] = value };
    const contexts = [];
    let handler;
    const binding = {
        attachCreateCompleted: fn => handler = fn,
        detachCreateCompleted: fn => { assert.equal(handler, fn); handler = undefined; },
        create: () => {
            const context = {
                transient: true, deleted: false,
                created: () => new Promise(() => {}), // UI5 keeps this pending on HTTP 400.
                isTransient() { return this.transient; },
                delete() { this.deleted = true; return Promise.resolve(); }
            };
            contexts.push(context);
            return context;
        }
    };
    const model = {
        submitBatch: async () => {
            if (respond) contexts.forEach(context => {
                context.transient = !success;
                handler({ getParameters: () => ({ context, success }) });
            });
        },
        getMessages: () => [{ getType: () => 'Error', getMessage: () => 'Invalid DurationHours' }]
    };
    return { controller, binding, model, contexts, state, detached: () => !handler };
}
test('HTTP 400 rejects promptly even though created() never settles; cancels failed creates', async () => {
    const s = setup(false);
    await assert.rejects(s.controller._createEntities(s.model, s.binding, [{}]), /Invalid DurationHours/);
    assert.equal(s.contexts[0].deleted, true);
    assert.equal(s.detached(), true);
});
test('successful header and role creates finish from POST completion', async () => {
    const s = setup();
    const result = await s.controller._createEntities(s.model, s.binding, [{}, {}]);
    assert.equal(result.length, 2);
    assert.equal(s.contexts.some(c => c.deleted), false);
    assert.equal(s.detached(), true);
});
test('missing response times out and prevents unsafe retry', async () => {
    const s = setup(true, false);
    s.controller.SUBMIT_TIMEOUT_MS = 10;
    await assert.rejects(s.controller._createEntities(s.model, s.binding, [{}]), /did not respond within/);
    assert.equal(s.state['/submission/timedOut'], true);
    assert.equal(s.detached(), true);
});
test('Save failure clears busy state and never reaches role persistence', async () => {
    const s = setup(false);
    s.controller.getView = () => ({ getModel: () => s.model });
    s.controller._ensureDraftContext = () => s.controller._createEntities(s.model, s.binding, [{}]);
    s.controller._persistRoles = () => assert.fail('must not assign roles after failed creation');
    await s.controller.onSaveDraft();
    assert.equal(s.controller._saveInFlight, false);
    assert.equal(s.state['/saveBusy'], false);
    assert.ok(hidden > 0);
});
test('Joiner sends numeric zero; Firefighter sends numeric duration', () => {
    for (const [type, expected] of [['J', 0], ['M', 0], ['L', 0], ['F', 2]]) {
        const s = setup();
        s.state['/request/ReqType'] = type;
        s.controller.byId = id => ({ getValue: () => id === 'durationHoursInput' ? '2' : 'TEST' });
        s.controller._syncRequestFromForm();
        assert.equal(s.state['/request'].DurationHours, expected);
    }
});
test('Firefighter duration respects the selected role maximum', () => {
    const s = setup();
    const request = {
        ReqType: 'F', TargetUser: 'FIREFIGHTER-USER', TicketId: 'INC-001', Reason: 'Emergency support', DurationHours: 3
    };
    const role = [{ RoleName: 'ZROLE_IAM_HR', MaxHours: 2 }];
    assert.match(s.controller._validateRequest(request, role), /configured maximum of 2 hour/);
    assert.equal(s.controller._validateRequest({ ...request, DurationHours: 2 }, role), undefined);
});
test('manual SoD creation failure clears spinner and releases operation lock', async () => {
    const s = setup(false);
    s.state['/request'] = { TargetUser: 'TEST' };
    s.controller._syncRequestFromForm = () => {};
    s.controller._syncRolePreviewFromTable = () => {};
    s.controller._getReviewRoles = () => [{ RoleName: 'Z_TEST' }];
    s.controller.getView = () => ({ getModel: () => s.model });
    s.controller._ensureDraftContext = () => s.controller._createEntities(s.model, s.binding, [{}]);
    await s.controller._checkSod();
    assert.equal(s.state['/sod'].checking, false);
    assert.equal(s.state['/sod'].checked, false);
    assert.equal(s.controller._sodCheckInFlight, null);
});
test('Submit stops when SoD action fails instead of treating it as no conflicts', async () => {
    const s = setup();
    s.state['/request'] = { TargetUser: 'TEST' };
    s.controller._syncRequestFromForm = () => {};
    s.controller._syncRolePreviewFromTable = () => {};
    s.controller._getReviewRoles = () => [{ RoleName: 'Z_TEST' }];
    s.model.bindContext = () => ({ execute: async () => { throw new Error('SoD service failed'); } });
    s.controller.getView = () => ({ getModel: () => s.model });
    await assert.rejects(s.controller._checkSod({}), /SoD service failed/);
    assert.equal(s.state['/sod'].checking, false);
    assert.equal(s.controller._sodCheckInFlight, null);
});
