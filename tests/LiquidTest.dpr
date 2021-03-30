program LiquidTest;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  TestLiquid in 'TestLiquid.pas',
  Liquid.Block in '..\src\Liquid.Block.pas',
  Liquid.Condition in '..\src\Liquid.Condition.pas',
  Liquid.Context in '..\src\Liquid.Context.pas',
  Liquid.Default in '..\src\Liquid.Default.pas',
  Liquid.Document in '..\src\Liquid.Document.pas',
  Liquid.Exceptions in '..\src\Liquid.Exceptions.pas',
  Liquid.Filters in '..\src\Liquid.Filters.pas',
  Liquid.Hash in '..\src\Liquid.Hash.pas',
  Liquid.Interfaces in '..\src\Liquid.Interfaces.pas',
  Liquid.Tag in '..\src\Liquid.Tag.pas',
  Liquid.Tags in '..\src\Liquid.Tags.pas',
  Liquid.Template in '..\src\Liquid.Template.pas',
  Liquid.Tuples in '..\src\Liquid.Tuples.pas',
  Liquid.Utils in '..\src\Liquid.Utils.pas',
  Liquid.Variable in '..\src\Liquid.Variable.pas';

{$R *.RES}

begin
  ReportMemoryLeaksOnShutdown := True;
  DUnitTestRunner.RunRegisteredTests;
end.

