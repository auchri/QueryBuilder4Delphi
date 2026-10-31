import test from 'node:test';
import assert from 'node:assert/strict';
import { generateSmokeProjects, smokeProjectTemplate } from '../generate-smoke.mjs';
import { readFile } from 'node:fs/promises';
import { smokeCases, smokeDialects } from '../smoke-cases.mjs';
test('Delphi smoke fixtures are regenerated from every supported dialect and feature case', async () => {
  const files = await generateSmokeProjects();
  assert.equal(files.size, Object.keys(smokeDialects).length * 2);
  for (const dialect of Object.keys(smokeDialects)) {
    const program = files.get(`ConverterSmoke${dialect}.dpr`);
    for (const fixture of smokeCases) {
      assert.ok(program.includes(`function Build${fixture.name}: IQuery;`), `${dialect}: ${fixture.name}`);
      assert.ok(program.includes(`S := Check('${fixture.name}', Build${fixture.name}`));
    }
    for (const check of ['CheckInteger(S.Bindings[4]', "CheckFloat(S.Bindings[1], '19.99')", 'function(Q: IQuery): IQuery', 'Value.IsType<Double> or Value.IsType<Extended>']) assert.ok(program.includes(check), `${dialect}: ${check}`);
    for (const bcd of ['Data.FmtBcd', 'StrToBcd', 'TValue.From<TBcd>']) assert.ok(!program.includes(bcd));
    assert.ok(program.includes('0.1, 19.99, 1.23, 0.125, 1.0, -0.000000000000000001'));
    assert.ok(!program.includes('function BuildQuery:'));
    assert.ok(program.includes('if Result.Bindings.Count <> ExpectedBindings then'));
    assert.ok(!program.includes('Length(Result.Bindings)'));
    assert.ok(!/(?<!\r)\n/.test(program), 'Delphi source must use CRLF');
    assert.ok(files.get(`ConverterSmoke${dialect}.dproj`).includes('<TargetedPlatforms>3</TargetedPlatforms>'));
  }
});
test('Delphi IDE projects have stable, unique GUIDs and console platform metadata', async () => {
  const files = await generateSmokeProjects();
  const regenerated = await generateSmokeProjects();
  const guids = new Set();
  for (const dialect of Object.keys(smokeDialects)) {
    const name = `ConverterSmoke${dialect}`;
    const project = files.get(`${name}.dproj`);
    const guid = project.match(/<ProjectGuid>(\{[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}\})<\/ProjectGuid>/)?.[1];
    assert.ok(guid, `${name}: missing or invalid project GUID`);
    assert.ok(!guids.has(guid), `${name}: duplicate project GUID`);
    guids.add(guid);
    assert.equal(project, regenerated.get(`${name}.dproj`));
    assert.ok(project.includes('<Borland.ProjectType>Console</Borland.ProjectType>'));
    assert.ok(project.includes(`<Source Name="MainSource">${name}.dpr</Source>`));
    for (const platform of ['Win32', 'Win64']) assert.ok(project.includes(`<Platform value="${platform}">True</Platform>`));
    assert.ok(!project.includes('Debugger_HostApplication'));
  }
});
test('smoke project configuration retains the working console project structure', async () => {
  const template = await readFile(smokeProjectTemplate, 'utf8');
  const files = await generateSmokeProjects();
  const groups = xml => [...xml.matchAll(/<PropertyGroup(?:\s+Condition="([^"]*)")?>/g)].map(match => match[1] || '');
  const imports = xml => [...xml.matchAll(/<Import\b[^>]*\/>/g)].map(match => match[0]);
  for (const dialect of Object.keys(smokeDialects)) {
    const name = `ConverterSmoke${dialect}`;
    const project = files.get(`${name}.dproj`);
    assert.deepEqual(groups(project), groups(template));
    assert.deepEqual(imports(project), imports(template));
    const baseOptions = project.match(/<PropertyGroup Condition="'\$\(Base\)'!=''">([\s\S]*?)<\/PropertyGroup>/)?.[1];
    assert.ok(baseOptions?.includes('<DCC_ExeOutput>'), 'IDE launch must resolve the configured executable output');
    assert.ok(!project.split('</PropertyGroup>')[0].includes('<DCC_'), 'compiler options must belong to the Base configuration');
    assert.ok(project.includes(`<SanitizedProjectName>${name}</SanitizedProjectName>`));
    assert.ok(project.includes('<DCC_ExeOutput>.\\$(Platform)</DCC_ExeOutput>'));
    assert.ok(project.includes('<DCC_DcuOutput>.\\$(Platform)\\dcu</DCC_DcuOutput>'));
    assert.ok(project.includes('<DCC_UnitSearchPath>..\\..\\src;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>'));
    assert.ok(!project.includes('DUnitX'));
    assert.ok(!project.includes('<DCCReference'));
  }
});
