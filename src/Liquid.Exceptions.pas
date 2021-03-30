unit Liquid.Exceptions;

interface

uses
  System.SysUtils;

type
  ELiquidException = class(Exception);
  ERenderException = class(Exception);

  ELiquidSyntaxException = class(ELiquidException);
  EStackLevelException = class(ELiquidException);
  EContextException = class(ELiquidException);
  EFilterNotFoundException = class(ELiquidException);
  EMaximumIterationsExceededException = class(ERenderException);

  EInterruptException = class(ELiquidException);
  EBreakInterrupt = class(EInterruptException)
  public
    constructor Create; reintroduce;
  end;
  EContinueInterrupt = class(EInterruptException)
  public
    constructor Create; reintroduce;
  end;

implementation

{ EBreakInterrupt }

constructor EBreakInterrupt.Create;
begin
  inherited Create('Misplaced ''break'' statement');
end;

{ EContinueInterrupt }

constructor EContinueInterrupt.Create;
begin
  inherited Create('Misplaced ''continue'' statement');
end;

end.
