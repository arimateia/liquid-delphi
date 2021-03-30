unit Liquid.Block;

interface

uses
  System.SysUtils, System.Generics.Collections,
  System.RegularExpressions, System.Classes,
  System.Rtti,

  Liquid.Interfaces,
  Liquid.Exceptions,
  Liquid.Tag,
  Liquid.Variable,
  Liquid.Context,
  Liquid.Default,
  Liquid.Utils;

type
  TBlock = class(TTag)
  strict private
    FIsTag: TRegEx;
    FIsVariable: TRegEx;
    FContentOfVariable: TRegEx;
    FFullToken: TRegEx;
    FObjects: TList<TObject>;
    function BlockName: string;
  protected
    procedure Parse(ATokens: TList<string>); override;
    function BlockDelimiter: string; virtual;
    procedure AssertMissingDelimitation; virtual;
    procedure RenderAll(ANodeList: INodeList; Context: ILiquidContext;
      Writer: TTextWriter);
    procedure AddToGarbage(AObject: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure EndTag; virtual;
    procedure UnknownTag(const Tag: string; const Markup: string;
      Tokens: TList<string>); virtual;
    function CreateVariable(const Token: string): TVariable;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

implementation

uses
  Liquid.Template;

{ TBlock }

procedure TBlock.AddToGarbage(AObject: TObject);
begin
  FObjects.Add(AObject);
end;

procedure TBlock.AssertMissingDelimitation;
begin
  raise ELiquidSyntaxException.CreateFmt(
    '%0:s tag was never closed', [BlockName]);
end;

function TBlock.BlockDelimiter: string;
begin
  Result := Format('end%s', [BlockName]);
end;

function TBlock.BlockName: string;
begin
  Result := TagName;
end;

constructor TBlock.Create;
begin
  inherited Create;
  FIsTag := R.B('^%s', [LiquidRegexes.TagStart]);
  FIsVariable := R.B('^%0:s', [LiquidRegexes.VariableStart]);
  FContentOfVariable := R.B('^%0:s(.*)%1:s$', [LiquidRegexes.VariableStart, LiquidRegexes.VariableEnd]);
  FFullToken := R.B('^%0:s\s*(\w+)\s*(.*)?%1:s$', [LiquidRegexes.TagStart, LiquidRegexes.TagEnd]);
  FObjects := TObjectList<TObject>.Create;
end;

function TBlock.CreateVariable(const Token: string): TVariable;
begin
  var Match := FContentOfVariable.Match(Token);
  if Match.Success then
    Exit(TVariable.Create(Match.Groups[1].Value));
  raise ELiquidSyntaxException.CreateFmt(
    'Variable ''%0:s'' was not properly terminated with regexp: %1:s',
    [Token, LiquidRegexes.VariableEnd]);
end;

destructor TBlock.Destroy;
begin
  FObjects.Free;
  inherited;
end;

procedure TBlock.EndTag;
begin
end;

procedure TBlock.Parse(ATokens: TList<string>);
begin
  NodeList.Clear;
  while ATokens.Count > 0 do
  begin
    var Token := ATokens.ExtractAt(0);
    var IsTagMatch := FIsTag.Match(Token);
    if IsTagMatch.Success then
    begin
      var FullTokenMatch := FFullToken.Match(Token);
      if FullTokenMatch.Success then
      begin
        // If we found the proper block delimitor just end parsing here and let the outer block
        // proceed
        if BlockDelimiter = FullTokenMatch.Groups[1].Value then
        begin
          EndTag;
          Exit;
        end;

        // Fetch the tag from registered blocks
        var Tag := TLiquidTemplate.CreateTag(FullTokenMatch.Groups[1].Value);
        if Tag <> nil then
        begin
          AddToGarbage(Tag);
          Tag.Initialize(FullTokenMatch.Groups[1].Value,
            FullTokenMatch.Groups[2].Value, ATokens);
          NodeList.Add(Tag);

          // If the tag has some rules (eg: it must occur once) then check for them
          Tag.AssertTagRulesViolation(NodeList);
        end
        else
        begin
          // This tag is not registered with the system
          // pass it to the current block for special handling or error reporting
          UnknownTag(FullTokenMatch.Groups[1].Value, FullTokenMatch.Groups[2].Value,
            ATokens);
        end;
      end
      else
        raise ELiquidSyntaxException.CreateFmt(
          'Tag ''%0:s'' was not properly terminated with regexp: %1:s',
          [Token, LiquidRegexes.TagEnd]);
    end
    else if FIsVariable.Match(Token).Success then
    begin
      var Variable := CreateVariable(Token);
      NodeList.Add(Variable);
      AddToGarbage(Variable);
    end
    else if Token.IsEmpty then
    begin
      // Pass
    end
    else
      NodeList.Add(Token);
  end;
end;

procedure TBlock.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  RenderAll(NodeList, Context, Writer);
end;

procedure TBlock.RenderAll(ANodeList: INodeList; Context: ILiquidContext;
  Writer: TTextWriter);
begin
  for var Token in ANodeList do
  begin
    try
      if Token.IsType<TVariable> then
        Token.AsType<TVariable>.Render(Context, Writer)
      else if Token.IsType<TTag> then
        Token.AsType<TTag>.Render(Context, Writer)
      else
        Writer.Write(Token.AsString);
    except
      on E: ELiquidException do
      begin
        var Msg: string;
        if Context.HandleError(E, Msg) then
          Writer.Write(Msg)
        else
          raise;
      end;
    end;
  end;
end;

procedure TBlock.UnknownTag(const Tag, Markup: string; Tokens: TList<string>);
begin
  if Tag = 'else' then
    raise ELiquidSyntaxException.CreateFmt('%0:s tag does not expect else tag',
      [BlockName])
  else if Tag = 'end' then
    raise ELiquidSyntaxException.CreateFmt(
      '''end'' is not a valid delimiter for %0:s tags. Use %1:s',
      [BlockName, BlockDelimiter])
  else
    raise ELiquidSyntaxException.CreateFmt('Unknown tag ''%0:s''',
      [Tag]);
end;

end.
