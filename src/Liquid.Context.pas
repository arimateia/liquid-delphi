unit Liquid.Context;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes, System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  System.Rtti,

  Liquid.Interfaces,
  Liquid.Default,
  Liquid.Hash,
  Liquid.Filters,
  Liquid.Exceptions,
  Liquid.Utils;

type
  TLiquidContext = class(TInterfacedObject, ILiquidContext)
  strict private
    //
    FErrorsOutputMode: TErrorsOutputMode;
    FMaxIterations: integer;
    FEnvironments: TList<IHash>;
    FScopes: TList<IHash>;
    FRegisters: IHash;
    FErrors: TList<string>;
    FFormatSettings: TFormatSettings;
    FStrainer: IStrainer;
  private
    function Variable(const Markup: string; NotifyNotFound: boolean): TValue;
    function FindVariable(const Key: string): TValue;
    function LookupAndEvaluate(Value: TValue; const Key: string): TValue;
  private
    function Resolve(const Key: string): TValue; overload;
    function Resolve(const Key: string; NotifyNotFound: boolean): TValue; overload;
    procedure SetVariable(const Key: string; const Value: TValue);
    function GetEnvironments: TList<IHash>;
    function GetErrors: TList<string>;
    function GetErrorsOutputMode: TErrorsOutputMode;
    function GetFormatSettings: TFormatSettings;
    function GetMaxIterations: integer;
    function GetRegisters: IHash;
    function GetScopes: TList<IHash>;
    function GetStrainer: IStrainer;
    procedure SetErrorsOutputMode(const Value: TErrorsOutputMode);
  public
    class function Liquidize(Value: TValue): TValue;
    constructor Create(AEnvironments: TList<IHash>; AOuterScope: IHash;
      ARegisters: IHash; AErrorsOutputMode: TErrorsOutputMode;
      AMaxIterations: integer; AFormatSettings: TFormatSettings); overload;
    constructor Create(AFormatSettings: TFormatSettings); overload;
    destructor Destroy; override;
    function HandleError(E: Exception; var Msg: string): boolean;
    procedure Push(NewScope: IHash);
    procedure Merge(NewScope: IHash);
    function Pop: IHash;
    procedure Stack(Callback: TProc); overload;
    procedure Stack(NewScope: IHash; Callback: TProc); overload;
    procedure ClearInstanceAssigns;
    function HasKey(const Key: string): boolean;
    property ErrorsOutputMode: TErrorsOutputMode read GetErrorsOutputMode write SetErrorsOutputMode;
    property MaxIterations: integer read GetMaxIterations;
    property Environments: TList<IHash> read GetEnvironments;
    property Scopes: TList<IHash> read GetScopes;
    property Registers: IHash read GetRegisters;
    property Strainer: IStrainer read GetStrainer;
    property Errors: TList<string> read GetErrors;
    property FormatSettings: TFormatSettings read GetFormatSettings;
    property Items[const Key: string]: TValue read Resolve write SetVariable; default;
    property Items[const Key: string; NotifyNotFound: boolean]: TValue read Resolve; default;
  end;

implementation

{ TLiquidContext }

procedure TLiquidContext.ClearInstanceAssigns;
begin
  FScopes[0].Clear;
end;

constructor TLiquidContext.Create(AEnvironments: TList<IHash>;
  AOuterScope: IHash; ARegisters: IHash; AErrorsOutputMode: TErrorsOutputMode;
  AMaxIterations: integer; AFormatSettings: TFormatSettings);
begin
  FEnvironments := AEnvironments;
  FScopes := TList<IHash>.Create;
  if AOuterScope <> nil then
    FScopes.Add(AOuterScope);
  FRegisters := ARegisters;
  FErrors := TList<string>.Create;
  FErrorsOutputMode := AErrorsOutputMode;
  FMaxIterations := AMaxIterations;
  FFormatSettings := AFormatSettings;
  FStrainer := TStrainer.Create(Self);
end;

constructor TLiquidContext.Create(AFormatSettings: TFormatSettings);
begin
  Create(TList<IHash>.Create, THash.Create,
      THash.Create, TErrorsOutputMode.Rethrow, 0, AFormatSettings)
end;

destructor TLiquidContext.Destroy;
begin
  FEnvironments.Free;
  FScopes.Free;
  FRegisters := nil;
  FErrors.Free;
  inherited;
end;

function TLiquidContext.FindVariable(const Key: string): TValue;
begin
  var Scope: IHash := nil;
  for var S in FScopes do
    if S.ContainsKey(Key) then
    begin
      Scope := S;
      Break;
    end;
  var Variable := TValue.Empty;
  if Scope = nil then
  begin
    for var E in Environments do
    begin
      Variable := LookupAndEvaluate(TValue.From<IHash>(E), Key);
      if not Variable.IsEmpty then
      begin
        Scope := E;
        Break;
      end;
    end;
  end;
  if Scope = nil then
  begin
    if Environments.Count > 0 then
      Scope := Environments.Last;
    if Scope = nil then
      Scope := FScopes.Last;
  end;
  if Variable.IsEmpty then
    Variable := LookupAndEvaluate(TValue.From<IHash>(Scope), Key);
  Result := Variable;
end;

function TLiquidContext.GetEnvironments: TList<IHash>;
begin
  Result := FEnvironments;
end;

function TLiquidContext.GetErrors: TList<string>;
begin
  Result := FErrors;
end;

function TLiquidContext.GetErrorsOutputMode: TErrorsOutputMode;
begin
  Result := FErrorsOutputMode;
end;

function TLiquidContext.GetFormatSettings: TFormatSettings;
begin
  Result := FFormatSettings;
end;

function TLiquidContext.GetMaxIterations: integer;
begin
  Result := FMaxIterations;
end;

function TLiquidContext.GetRegisters: IHash;
begin
  Result := FRegisters;
end;

function TLiquidContext.GetScopes: TList<IHash>;
begin
  Result := FScopes;
end;

function TLiquidContext.GetStrainer: IStrainer;
begin
  Result := FStrainer;
end;

function TLiquidContext.HandleError(E: Exception; var Msg: string): boolean;
begin
  Msg := '';
  if (E is EInterruptException) or (E is ERenderException) then
    Exit(False);

  if E is ELiquidSyntaxException then
    Msg := Format('Liquid syntax error: %s', [E.Message])
  else
    Msg := Format('Liquid error: %s', [E.Message]);
  FErrors.Add(Msg);

  if FErrorsOutputMode = TErrorsOutputMode.Suppress then
    Exit(True);

  if FErrorsOutputMode = TErrorsOutputMode.Rethrow then
    Exit(False);

  if E is ELiquidSyntaxException then
    Exit(True);

  Result := True;
end;

function TLiquidContext.HasKey(const Key: string): boolean;
begin
  var Value := Resolve(Key, False);
  Result := not Value.IsEmpty;
end;

class function TLiquidContext.Liquidize(Value: TValue): TValue;
begin
  Result := Value;
end;

function TLiquidContext.LookupAndEvaluate(Value: TValue;
  const Key: string): TValue;
begin
  if Value.IsType<IHash> then
    Result := Value.AsType<IHash>[Key]
  else if Value.IsType<TArray<TValue>> then
  begin
    Result := Value.AsType<TArray<TValue>>[StrToInt(Key)];
  end
  else
    raise ENotSupportedException.Create('');
end;

procedure TLiquidContext.Merge(NewScope: IHash);
begin
  for var Pair in NewScope.ToArray do
    FScopes[0].AddOrSetValue(Pair.Key, Pair.Value);
end;

function TLiquidContext.Pop: IHash;
begin
  if FScopes.Count = 1 then
    raise EContextException.Create('Context error in pop operation');
  Result := FScopes.ExtractAt(0);
end;

procedure TLiquidContext.Push(NewScope: IHash);
begin
  if FScopes.Count > 80 then
    raise EStackLevelException.Create('Nesting too deep');
  FScopes.Insert(0, NewScope);
end;

function TLiquidContext.Resolve(const Key: string): TValue;
begin
  Result := Resolve(Key, True);
end;

function TLiquidContext.Resolve(const Key: string;
  NotifyNotFound: boolean): TValue;
begin
  var Output: TValue;
  if TConverter.StringToRealType(Key, Output) then
    Exit(Output);
  Result := Variable(Key, NotifyNotFound);
end;

procedure TLiquidContext.Stack(Callback: TProc);
begin
  var NewScope: IHash := THash.Create;
  Stack(NewScope, Callback);
end;

procedure TLiquidContext.SetErrorsOutputMode(const Value: TErrorsOutputMode);
begin
  FErrorsOutputMode := Value;
end;

procedure TLiquidContext.SetVariable(const Key: string; const Value: TValue);
begin
  FScopes[0][Key] := Value;
end;

procedure TLiquidContext.Stack(NewScope: IHash; Callback: TProc);
begin
  Push(NewScope);
  try
    Callback();
  finally
    Pop;
  end;
end;

function TLiquidContext.Variable(const Markup: string;
  NotifyNotFound: boolean): TValue;
begin
  var Parts := R.Scan(Markup, LiquidRegexes.VariableParserRegex);
  var FirstPart: string;
  if Length(Parts) > 0 then
    FirstPart := Parts[0]
  else
    FirstPart := '';

  var FirstPartSquareBracketedMatch := LiquidRegexes.SquareBracketedRegex.Match(FirstPart);
  if FirstPartSquareBracketedMatch.Success then
    FirstPart := Resolve(FirstPartSquareBracketedMatch.Groups[1].Value).AsString;

  var Value := FindVariable(FirstPart);
  if Value.IsEmpty then
  begin
    if NotifyNotFound then
      Errors.Add(Format('Variable ''%s'' could not be found', [Markup]));
    Exit(TValue.Empty);
  end;

  // try to resolve the rest of the parts (starting from the second item in the list)
  for var I := 1 to Length(Parts) - 1 do
  begin
    var ForEachPart := Parts[i];

    var PartSquareBracketedMatch := LiquidRegexes.SquareBracketedRegex.Match(ForEachPart);
    var PartResolved := PartSquareBracketedMatch.Success;

    var Part: TValue := ForEachPart;
    if PartResolved then
      Part := Resolve(PartSquareBracketedMatch.Groups[1].Value);

    if Value.IsType<IHash> then
    begin
      var Res := LookupAndEvaluate(Value, Part.AsString);
      Value := Liquidize(Res);
    end
    else if (not PartResolved) and (Value.IsArray) and (Part.AsString.Equals('size') or Part.AsString.Equals('first') or Part.AsString.Equals('last')) then
    begin
      var ArrayValue := Value.AsType<TArray<TValue>>;
      if Part.AsString.Equals('size') then
        Value := Length(ArrayValue)
      else
      begin
        if Length(ArrayValue) = 0 then
          Value := TValue.Empty
        else if Part.AsString.Equals('first') then
        begin
          var Res := ArrayValue[0];
          Value := Liquidize(Res);
        end
        else if Part.AsString.Equals('last') then
        begin
          var Res := ArrayValue[Length(ArrayValue) - 1];
          Value := Liquidize(Res);
        end;
      end;
    end
    else
    begin
      Errors.Add(Format('Error - Variable ''%s'' could not be found', [Markup]));
      Exit(TValue.Empty);
    end;
  end;

  Result := Value;
end;

end.
