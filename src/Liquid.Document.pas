unit Liquid.Document;

interface

uses
  System.SysUtils, System.Generics.Collections,
  System.RegularExpressions, System.Classes,

  Liquid.Interfaces,
  Liquid.Context,
  Liquid.Exceptions,
  Liquid.Tag,
  Liquid.Variable,
  Liquid.Block;

type
  TDocument = class(TBlock)
  strict private
  protected
    function BlockDelimiter: string; override;
    procedure AssertMissingDelimitation; override;
  public
    constructor Create;
    procedure Initialize(const ATagName: string; const AMarkup: string;
      ATokens: TList<string>); override;
    procedure Render(Context: ILiquidContext; TextWriter: TTextWriter); override;
  end;

implementation

{ TDocument }

procedure TDocument.AssertMissingDelimitation;
begin
  // pass
end;

function TDocument.BlockDelimiter: string;
begin
  Result := string.Empty;
end;

constructor TDocument.Create;
begin
  inherited Create;
end;

procedure TDocument.Initialize(const ATagName, AMarkup: string;
  ATokens: TList<string>);
begin
  Parse(ATokens);
end;

procedure TDocument.Render(Context: ILiquidContext; TextWriter: TTextWriter);
begin
  try
    inherited Render(Context, TextWriter);
  except
    on E: EBreakInterrupt do
    begin
      // BreakInterrupt exceptions are used to interrupt a rendering
    end;
    on E: EContinueInterrupt do
    begin
      // ContinueInterrupt exceptions are used to interrupt a rendering
    end;
  end;
end;

end.
