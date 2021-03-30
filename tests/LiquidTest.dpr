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
  Liquid.Template in '..\Liquid.Template.pas',
  Liquid.Default in '..\Liquid.Default.pas',
  Liquid.Context in '..\Liquid.Context.pas',
  Liquid.Interfaces in '..\Liquid.Interfaces.pas',
  Liquid.Tag in '..\Liquid.Tag.pas',
  Liquid.Block in '..\Liquid.Block.pas',
  Liquid.Exceptions in '..\Liquid.Exceptions.pas',
  Liquid.Variable in '..\Liquid.Variable.pas',
  Liquid.Document in '..\Liquid.Document.pas',
  Liquid.Hash in '..\Liquid.Hash.pas',
  Liquid.Tuples in '..\Liquid.Tuples.pas',
  Liquid.Condition in '..\Liquid.Condition.pas',
  Liquid.Utils in '..\Liquid.Utils.pas',
  Liquid.Tags in '..\Liquid.Tags.pas',
  Liquid.Filters in '..\Liquid.Filters.pas';

{$R *.RES}

begin
  ReportMemoryLeaksOnShutdown := True;
  DUnitTestRunner.RunRegisteredTests;
end.

