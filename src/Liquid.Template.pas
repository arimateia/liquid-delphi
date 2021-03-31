unit Liquid.Template;

interface

uses
  System.SysUtils, System.Classes,
  System.Generics.Collections,
  System.RegularExpressions,

  Liquid.Interfaces,
  Liquid.Default,
  Liquid.Document,
  Liquid.Context,
  Liquid.Hash,
  Liquid.Tag,
  Liquid.Tags,
  Liquid.Tuples;

type
  TRenderParameters = class;

  TLiquidTemplate = class
  strict private
    class var
      FTags: TDictionary<string, ITuple<ITagFactory, TTagClass>>;
    class function Tags: TDictionary<string, ITuple<ITagFactory, TTagClass>>;
  strict private
    FRoot: TDocument;
    FInstanceAssigns: IHash;
  private
    procedure ParseInternal(ASource: TArray<byte>);
    procedure RenderInternal(Writer: TTextWriter; Parameters: TRenderParameters);
    function GetInstanceAssigns: IHash;
  protected
    function Tokenize(ASource: TArray<byte>): TList<string>; overload;
    function Tokenize(const ASource: string): TList<string>; overload;
  public
    class function Parse(const ASource: string): TLiquidTemplate; overload;
    class function Parse(ASource: TArray<byte>): TLiquidTemplate; overload;
    class function CreateTag(const Name: string): TTag;
    class procedure RegisterTagFactory(TagFactory: ITagFactory);
    class procedure RegisterTag(ATagClass: TTagClass; const AName: string);
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;
    function Render: string; overload;
    function Render(FormatSettings: TFormatSettings): string; overload;
    function Render(LocalVariables: IHash; FormatSettings: TFormatSettings): string; overload;
    function Render(Parameters: TRenderParameters): string; overload;
    function Render(Writer: TTextWriter; Parameters: TRenderParameters): string; overload;
    property InstanceAssigns: IHash read GetInstanceAssigns;
  end;

  TRenderParameters = class
  strict private
    FContext: ILiquidContext;
    FLocalVariables: IHash;
    FRegisters: IHash;
    // FFilters

    FErrorsOutputMode: TErrorsOutputMode;
    FMaxIterations: integer;
    FFormatSettings: TFormatSettings;
  private
    procedure SetLocalVariables(ALocalVariables: IHash);
  public
    class function FromContext(AContext: ILiquidContext;
      AFormatSettings: TFormatSettings): TRenderParameters;
  public
    constructor Create(AFormatSettings: TFormatSettings);
    destructor Destroy; override;
    procedure Evaluate(Template: TLiquidTemplate; out Context: ILiquidContext;
      out Registers: IHash);
    property ErrorsOutputMode: TErrorsOutputMode read FErrorsOutputMode;
    property MaxIterations: integer read FMaxIterations;
  end;

implementation

uses
  System.Rtti;

{ TLiquidTemplate }

constructor TLiquidTemplate.Create;
begin

end;

class function TLiquidTemplate.CreateTag(const Name: string): TTag;
begin
  Result := nil;
  var Tuple: ITuple<ITagFactory, TTagClass> := nil;
  if Tags.TryGetValue(Name, Tuple) then
    Result := Tuple.Value1.CreateTag;
end;

class destructor TLiquidTemplate.Destroy;
begin
  FTags.Free;
end;

destructor TLiquidTemplate.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TLiquidTemplate.GetInstanceAssigns: IHash;
begin
  if FInstanceAssigns = nil then
    FInstanceAssigns := THash.Create;
  Result := FInstanceAssigns;
end;

class function TLiquidTemplate.Parse(ASource: TArray<byte>): TLiquidTemplate;
begin
  Result := TLiquidTemplate.Create;
  try
    Result.ParseInternal(ASource);
  except
    Result.Free;
    raise;
  end;
end;

procedure TLiquidTemplate.ParseInternal(ASource: TArray<byte>);
begin
//  source = DotLiquid.Tags.Literal.FromShortHand(source);
//  source = DotLiquid.Tags.Comment.FromShortHand(source);

  var Tokens := Tokenize(ASource);
  try
    FRoot := TDocument.Create;
    FRoot.Initialize('', '', Tokens);
  finally
    Tokens.Free;
  end;
end;

class function TLiquidTemplate.Parse(const ASource: string): TLiquidTemplate;
begin
  Result := Parse(TEncoding.UTF8.GetBytes(ASource));
end;

function TLiquidTemplate.Render(LocalVariables: IHash;
  FormatSettings: TFormatSettings): string;
begin
  var Parameters := TRenderParameters.Create(FormatSettings);
  try
    Parameters.SetLocalVariables(LocalVariables);
    Result := Render(Parameters);
  finally
    Parameters.Free;
  end;
end;

class procedure TLiquidTemplate.RegisterTag(ATagClass: TTagClass;
  const AName: string);
begin
  Tags.AddOrSetValue(AName, TTuple<ITagFactory, TTagClass>.Create(
    TRttiTagFactory.Create(ATagClass, AName), ATagClass));
end;

class procedure TLiquidTemplate.RegisterTagFactory(TagFactory: ITagFactory);
begin
  Tags.AddOrSetValue(TagFactory.TagName, TTuple<ITagFactory, TTagClass>.Create(
    TagFactory, nil));
end;

function TLiquidTemplate.Render(Writer: TTextWriter;
  Parameters: TRenderParameters): string;
begin
  if Writer = nil then
    raise EArgumentNilException.Create('Writer is missing');
  if Parameters = nil then
    raise EArgumentNilException.Create('Parameters is missing');
  RenderInternal(Writer, Parameters);
  Result := Writer.ToString;
end;

function TLiquidTemplate.Render(FormatSettings: TFormatSettings): string;
begin
  var Parameters := TRenderParameters.Create(FormatSettings);
  try
    Result := Render(Parameters);
  finally
    Parameters.Free;
  end;
end;

function TLiquidTemplate.Render: string;
begin
  Result := Render(TFormatSettings.Invariant);
end;

procedure TLiquidTemplate.RenderInternal(Writer: TTextWriter;
  Parameters: TRenderParameters);
begin
  if FRoot = nil then
    Exit;

  var Context: ILiquidContext;
  var Registers: IHash;
  Parameters.Evaluate(Self, Context, Registers);
  FRoot.Render(Context, Writer);
end;

class function TLiquidTemplate.Tags: TDictionary<string, ITuple<ITagFactory, TTagClass>>;
begin
  if FTags = nil then
    FTags := TDictionary<string, ITuple<ITagFactory, TTagClass>>.Create;
  Result := FTags;
end;

function TLiquidTemplate.Tokenize(const ASource: string): TList<string>;
begin
  Result := Tokenize(TEncoding.UTF8.getbytes(ASource));
end;

function TLiquidTemplate.Render(Parameters: TRenderParameters): string;
begin
  var Writer := TStringWriter.Create;
  try
    Result := Render(Writer, Parameters);
  finally
    Writer.Free;
  end;
end;

function TLiquidTemplate.Tokenize(ASource: TArray<byte>): TList<string>;
begin
  var Source := TEncoding.UTF8.GetString(ASource);
  if string.IsNullOrEmpty(Source) then
    Exit(TList<string>.Create);

//  // Trim leading whitespace.
//  Source := TRegEx.Replace(Source,
//    Format('([ \t]+)?(%0:s|%1:s)', [FLiquid.VariableStart, FLiquid.TagStart]),
//    '$2', [roNone]);
//
//  // Trim trailing whitespace.
//  Source := TRegEx.Replace(Source,
//    Format('(%0:s|%1:s)(\n|\r\n|[ \t]+)?', [FLiquid.VariableEnd, FLiquid.TagEnd]),
//    '$1', [roNone]);

  Result := TList<string>.Create;
  try
    var Pattern := LiquidRegexes.TemplateParser;
    Result.AddRange(TRegEx.Split(Source, Pattern));

    // Trim any whitespace elements from the end of the array.
    for var I := Result.Count - 1 downto 0 do
      if Result[I].IsEmpty then
        Result.Delete(I);

    // Removes the rogue empty element at the beginning of the array
    if (Result.Count > 0) and (Result.First.IsEmpty) then
      Result.ExtractAt(0);
  except
    Result.Free;
    raise;
  end;
end;

{ TRenderParameters }

constructor TRenderParameters.Create(AFormatSettings: TFormatSettings);
begin
  FMaxIterations := 0;
  FFormatSettings := AFormatSettings;
end;

destructor TRenderParameters.Destroy;
begin
  FLocalVariables := nil;
  inherited;
end;

procedure TRenderParameters.Evaluate(Template: TLiquidTemplate;
  out Context: ILiquidContext; out Registers: IHash);
begin
  if FContext <> nil then
  begin
    Context := FContext;
    Registers := nil;
    // Filters := nil;
    Exit;
  end;
  var Environments := TList<IHash>.Create;
  if FLocalVariables <> nil then
    Environments.Add(FLocalVariables);

  Context := TLiquidContext.Create(Environments, THash.Create, THash.Create,
    FErrorsOutputMode, FMaxIterations, FFormatSettings);

  Registers := FRegisters;
  // Filters := FFilster;
end;

class function TRenderParameters.FromContext(AContext: ILiquidContext;
  AFormatSettings: TFormatSettings): TRenderParameters;
begin
  if AContext = nil then
    raise EArgumentException.Create('Context');
  Result := TRenderParameters.Create(AFormatSettings);
  Result.FContext := AContext;
end;

procedure TRenderParameters.SetLocalVariables(ALocalVariables: IHash);
begin
  FLocalVariables := ALocalVariables;
end;

end.
