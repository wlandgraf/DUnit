{ $Id: TestExtensions.pas 41 2011-04-16 01:13:25Z medington $ }
{: DUnit: An XTreme testing framework for Delphi programs.
   @author  The DUnit Group.
   @version $Revision: 41 $
}
(*
 * The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is DUnit.
 *
 * The Initial Developers of the Original Code are Kent Beck, Erich Gamma,
 * and Juancarlo A�ez.
 * Portions created The Initial Developers are Copyright (C) 1999-2000.
 * Portions created by The DUnit Group are Copyright (C) 2000-2004.
 * All rights reserved.
 *
 * Contributor(s):
 * Kent Beck <kentbeck@csi.com>
 * Erich Gamma <Erich_Gamma@oti.com>
 * Juanco A�ez <juanco@users.sourceforge.net>
 * Chris Morris <chrismo@users.sourceforge.net>
 * Jeff Moore <JeffMoore@users.sourceforge.net>
 * Kenneth Semeijn <kennethsem@users.sourceforge.net>
 * Kris Golko <neuromancer@users.sourceforge.net>
 * The DUnit group at SourceForge <http://dunit.sourceforge.net>
 *
 *)
{$IFDEF ANDROID}
   {$DEFINE ANDROID_FIXME}
{$ENDIF}

// memory calculations may produce integer overflows
{$OVERFLOWCHECKS OFF}
unit TestExtensions;

{$IF CompilerVersion >= 24.0}
{$LEGACYIFEND ON}
{$IFEND}

interface

uses
{$IFDEF CLR}
  Classes,
  IniFiles,
{$ELSE !CLR}
  System.Classes,
  System.IniFiles,
{$ENDIF CLR}
  TestFramework,
  DUnitConsts;

type
  TMemorySize = Longint;

  {:A Decorator for Tests. Use TTestDecorator as the base class
    for defining new test decorators. Test decorator subclasses
    can be introduced to add behaviour before or after a test
    is run. }
  TTestDecorator = class(TAbstractTest, ITestDecorator, ITest)
  protected
    FName:  string;
    FTest:  ITest;
    FTests: IInterfaceList;

    function GetTest: ITest;

    {: Overrides the inherited behavior and executes the
       decorated test's RunTest instead }
    procedure RunTest(ATestResult: TTestResult); override;

  public
    {: Decorate a test. If no name parameter is given, the decorator
       will be named as the decorated test, with some extra information
       prepended.
       @param ATest The test to decorate.
       @param AName  Optional name to give to the decorator. }
    constructor Create(ATest: ITest; AName: string = '');

    function  CountTestCases: integer;          override;
    function  CountEnabledTestCases: integer;   override;

    { ITestDecorator implementation }
    function  GetName: string;                  override;
    function  Tests: IInterfaceList;            override;

    procedure LoadConfiguration(const iniFile :TCustomIniFile; const section :string);  override;
    procedure SaveConfiguration(const iniFile :TCustomIniFile; const section :string);  override;

    property Test: ITest read GetTest;
  end;

  {:A Decorator to set up and tear down additional fixture state.
    Subclass TestSetup and insert it into your tests when you want
    to set up additional state once before the tests are run.
    @example <br>
    <code>
    function UnitTests: ITest;
    begin
      Result := TSetubDBDecorator.Create(TDatabaseTests.Suite, 10);
    end; </code> }
  TTestSetup = class(TTestDecorator)
  protected
  public
    constructor Create(ATest: ITest; AName: string = '');

    function  GetName: string;                  override;

    // default decorator behavior is enough to provide for Setup decoration
    // procedure RunTest(ATestResult: TTestResult); override;
  end;

 {:A test decorator that runs a test repeatedly.
   Use TRepeatedTest to run a given test or suite a specific number
   of times.
    @example <br>
    <code>
    function UnitTests: ITestSuite;
    begin
      Result := TRepeatedTest.Create(ATestArithmetic.Suite, 10);
    end;
    </code> }

  {: General interface for test decorators}
  IRepeatedTest = interface(IUnknown)
  ['{DF3B52FF-2645-42C2-958A-174FF87A19B8}']

    function  GetHaltOnError: Boolean;
    procedure SetHaltOnError(const Value: Boolean);
    property  HaltOnError: Boolean read GetHaltOnError write SetHaltOnError;
  end;

  TRepeatedTest = class(TTestDecorator, IRepeatedTest)
  private
    FTimesRepeat: integer;
    FHaltOnError: Boolean;

    function  GetHaltOnError: Boolean;
    procedure SetHaltOnError(const Value: Boolean);
  protected
    {: Overrides the behavior of the base class as to execute
       the test repeatedly. }
    procedure RunTest(ATestResult: TTestResult);  override;

  public
    {: Construct decorator that repeats the decorated test.
       The ITest parameter can hold a single test or a suite. The Name parameter
       is optional.
       @param ATest The test to repeat.
       @param Itrations The number of times to repeat the test.
       @param AName An optional name to give to the decorator instance }
    constructor Create(ATest: ITest; Iterations: integer; AName: string = '');
    function  GetName: string;                    override;

    {: Overrides the inherited behavior to included the number of repetitions.
       @return Iterations * inherited CountTestCases }
    function  CountTestCases: integer;            override;

    {: Overrides the inherited behavior to included the number of repetitions.
       @return Iterations * inherited CountEnabledTestCases }
    function  CountEnabledTestCases: integer;     override;

  published
    property  HaltOnError: Boolean read GetHaltOnError write SetHaltOnError;
  end;

  {: A test decorator for running tests in a separate thread
     @todo Implement this class }
  TActiveTest = class(TTestDecorator)
  end;

  {: A test decorator for running tests expecting a specific exceptions
     to be thrown.
     @todo Implement this class }
  TExceptionTestCase = class(TTestDecorator)
  end;

  {: A test decorator for running tests while checking memory when a test is
   successful, expecting the memory to be equal before and after the SetUp,
   Run and TearDown.
   This decorator does not function correctly when the tested code
   creates singleton objects or strings that are not set to ''.
   Testing after the normal test run tests the memory with singletons in place.
    @example <br>
    <code>
    function UnitTests: ITestSuite;
    begin
      Result := TMemoryTest.Create(ATestArithmetic.Suite);
    end;
    </code> }

{$IFNDEF CLR}
{$IFNDEF MACOS}
  EMemoryError = class(ETestFailure);

  TMemoryTestTypes = (mttMemoryTestBeforeNormalTest, mttExecuteNormalTest, mttMemoryTestAfterNormalTest);
  TMemoryTestTypesSet = set of TMemoryTestTypes;

  TMemoryTest = class(TTestDecorator)
  protected
    function MemoryAllocated: TMemorySize;
  public
    function GetName : string; override;
    procedure RunTest(ATestResult: TTestResult); override;
  end;
{$ENDIF}
{$ENDIF}

implementation

uses
{$IFDEF FASTMM}
   FastMM4,
{$ENDIF}
{$IFDEF CLR}
  SysUtils;
{$ELSE !CLR}
  System.SysUtils;
{$ENDIF CLR}

{ TTestDecorator }

procedure TTestDecorator.RunTest(ATestResult: TTestResult);
begin
  FTest.RunWithFixture(ATestResult);
end;

function TTestDecorator.CountEnabledTestCases: integer;
begin
  if Enabled then
    Result := FTest.countEnabledTestCases
  else
    Result := 0;
end;

function TTestDecorator.CountTestCases: integer;
begin
  if Enabled then
    Result := FTest.countTestCases
  else
    Result := 0;
end;

constructor TTestDecorator.Create(ATest: ITest; AName: string);
begin
  if AName <> '' then
    inherited Create(AName)
  else
    inherited Create(ATest.Name);
  FTest := ATest;
  FTests:= TInterfaceList.Create;
  FTests.Add(FTest);
end;

function TTestDecorator.GetTest: ITest;
begin
  Result := FTest;
end;

procedure TTestDecorator.LoadConfiguration(const iniFile: TCustomIniFile; const section: string);
var
  i    : integer;
  LTests: IInterfaceList;
begin
  inherited LoadConfiguration(iniFile, section);
  LTests := self.Tests;
  for i := 0 to LTests.count-1 do
    (LTests[i] as ITest).LoadConfiguration(iniFile, section + '.' + self.GetName);
end;

procedure TTestDecorator.SaveConfiguration(const iniFile: TCustomIniFile; const section: string);
var
  i    : integer;
  LTests: IInterfaceList;
begin
  inherited SaveConfiguration(iniFile, section);
  LTests := self.Tests;
  for i := 0 to LTests.count-1 do
    (LTests[i] as ITest).SaveConfiguration(iniFile, section + '.' + self.GetName);
end;

function TTestDecorator.tests: IInterfaceList;
begin
  Result := FTests;
end;

function TTestDecorator.GetName: string;
begin
  Result := Format('(d) %s', [getTest.Name]);
end;

type
  {
    TTestSetupStub

    This class decorates the Setup decorator
    when called with then
    TTestSetup.CreateDecoratedTest function.
  }
  TTestSetupStub = class(TTestSetup)
  private
    FStubTest : ITest;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  end;

{ TTestSetupStub }

procedure TTestSetupStub.SetUp;
begin
  // Delegate the set up to the real implementation
  FStubTest.SetUp;
end;

procedure TTestSetupStub.TearDown;
begin
  // Delegate the teardown to the real implementation
  FStubTest.TearDown;
end;

{ TTestSetup }

constructor TTestSetup.Create(ATest: ITest; AName: string);
begin
  inherited Create(ATest, AName);
end;

function TTestSetup.GetName: string;
begin
  Result := Format(sSetupDecorator, [inherited GetName]);
end;

{ TRepeatedTest }

function TRepeatedTest.CountEnabledTestCases: integer;
begin
  Result := inherited CountEnabledTestCases * FTimesRepeat;
end;

function TRepeatedTest.CountTestCases: integer;
begin
  Result := inherited CountTestCases * FTimesRepeat;
end;

constructor TRepeatedTest.Create(ATest: ITest; Iterations: integer;
  AName: string);
begin
  inherited Create(ATest, AName);
  FTimesRepeat := Iterations;
end;

function TRepeatedTest.GetHaltOnError: Boolean;
begin
  Result := FHaltOnError;
end;

procedure TRepeatedTest.SetHaltOnError(const Value: Boolean);
begin
  FHaltOnError := Value;
end;

function TRepeatedTest.GetName: string;
begin
  Result := Format('%d x %s', [FTimesRepeat, getTest.Name]);
end;

procedure TRepeatedTest.RunTest(ATestResult: TTestResult);
var
  i: integer;
  ErrorCount: Integer;
  FailureCount: integer;
begin
  assert(assigned(ATestResult));

  ErrorCount := ATestResult.ErrorCount;
  FailureCount := ATestResult.FailureCount;

  for i := 0 to FTimesRepeat - 1 do
  begin
    if ATestResult.shouldStop or
      (Self.HaltOnError and
      ((ATestResult.ErrorCount > ErrorCount) or
       (ATestResult.FailureCount > FailureCount))) then
      Break;
    inherited RunTest(ATestResult);
  end;
end;

{ TMemoryTest }
{$IFNDEF CLR}
{$IFNDEF MACOS}
function TMemoryTest.GetName: string;
begin
  Result := Format(sTestMemory, [getTest.Name]);
end;

function TMemoryTest.MemoryAllocated: TMemorySize;
begin
{$IFDEF ANDROID_FIXME}
  Result := 0;
{$ELSE IFDEF LINUX}
                                                   
  Result := 0;
{$ELSE}
  {$IFDEF FASTMM}
    Result := FastMM4.FastGetHeapStatus.TotalAllocated;
  {$ELSE}
    {$IFDEF CONDITIONALEXPRESSIONS }  // Delphi 6+ or Kylix
      {$WARN SYMBOL_DEPRECATED OFF}   // Ignore the deprecated warning
      {$WARN SYMBOL_PLATFORM OFF}     // Ignore the platform warning
      {$IF CompilerVersion >= 18.0}   // Delphi 2006+
        Result := GetHeapStatus.TotalAllocated;
      {$IFEND}
      {$IF CompilerVersion < 18.0}    // Delphi 2005- (cannot use an $ELSE here)
        Result := AllocMemSize;
      {$IFEND}
      {$WARN SYMBOL_PLATFORM ON}
      {$WARN SYMBOL_DEPRECATED ON}
    {$ELSE}
      Result := GetHeapStatus.TotalAllocated;
    {$ENDIF}
  {$ENDIF}
{$ENDIF ANDROID_FIXME}
end;

procedure TMemoryTest.RunTest(ATestResult: TTestResult);
var
  LocalResult :TTestResult;
  Memory      :TMemorySize;
begin
  LocalResult := TTestResult.Create;
  try
    Memory := MemoryAllocated;
    FTest.RunWithFixture(LocalResult);
    Memory := MemoryAllocated - Memory;

    if LocalResult.WasSuccessful then
      CheckEquals(0, Memory, Format(sMemoryChanged, [Memory]))
    else
      inherited;
  finally
    LocalResult.Free;
  end;
end;
{$ENDIF}
{$ENDIF}

{$IF CompilerVersion >= 24.0}
{$LEGACYIFEND OFF}
{$ENDIF}
end.

