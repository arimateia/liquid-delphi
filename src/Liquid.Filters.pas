unit Liquid.Filters;

interface

uses
  System.SysUtils,
  System.Classes, System.Math,
  System.Generics.Collections,
  System.Rtti, System.TypInfo,
  System.Character,

  Liquid.Interfaces,
  Liquid.Tuples,
  Liquid.Utils;

type
  TStrainer = class(TInterfacedObject, IStrainer)
  strict private
    class var
      //FFilters: TDictionary<string, IFilter>;
      FFilterClasses: TDictionary<string, TClass>;
    class constructor Create;
    class destructor Destroy;
  strict private
    [Weak]
    FContext: ILiquidContext;
    FMethods: TDictionary<string, TClass>;
    function ResolveMethodName(const MethodName: string): string;
  public
    class procedure GlobalFilter(AClass: TClass);
  public
    constructor Create(AContext: ILiquidContext);
    destructor Destroy; override;
    function Invoke(const FilterName: string; Args: TArray<TValue>): TValue;
  end;

  TFilterFunc = reference to function(Context: ILiquidContext;
    const Input: TValue; const Args: TArray<TValue>): TValue;

  TGenericFilter = class(TInterfacedObject, IFilter)
  strict private
    FFunc: TFilterFunc;
  public
    constructor Create(AFilterFunc: TFilterFunc);
    function Filter(Context: ILiquidContext; const Input: TValue;
      const Args: TArray<TValue>): TValue;
  end;

  TStandardFilters = class
  strict private
  public
    function Default(const Input: string; const DefaultValue: string): string;
    function Upcase(const Input: string): string;
    function Downcase(const Input: string): string;
    function Append(const Input: string; const Value: string): string;
    function Date(Context: ILiquidContext; const Input: TDateTime; const Format: string): string;
    function Slice(const Input: string; Start: integer): string; overload;
    function Slice(const Input: string; Start: integer; Length: integer): string; overload;
    function Round(const Input: double): double; overload;
    function Round(const Input: double; Places: integer): double; overload;

    function FormatFloat(Context: ILiquidContext; const Input: integer;
      const Format: string): string; overload;
    function FormatFloat(Context: ILiquidContext; const Input: double;
      const Format: string): string; overload;
    function FormatFloat(Context: ILiquidContext; const Input: extended;
      const Format: string): string; overload;
  end;

implementation

{ TStrainer }

constructor TStrainer.Create(AContext: ILiquidContext);
begin
  FContext := AContext;
  FMethods := TDictionary<string, TClass>.Create;
  var RttiContext:= TRttiContext.Create;
  try
    for var C in FFilterClasses do
    begin
      for var Method in RttiContext.GetType(C.Value).GetDeclaredMethods do
      begin
        if Method.IsConstructor then
          Continue;
        if Method.ReturnType = nil then
          Continue;
        if FMethods.ContainsKey(Method.Name) and (FMethods[Method.Name] = C.Value) then
          Continue;
        FMethods.Add(Method.Name, C.Value);
      end;
    end;
  finally
    RttiContext.Free;
  end;
end;

class constructor TStrainer.Create;
begin
  FFilterClasses := TDictionary<string, TClass>.Create;
end;

class destructor TStrainer.Destroy;
begin
  FFilterClasses.Free;
end;

destructor TStrainer.Destroy;
begin
  FMethods.Free;
  inherited;
end;

class procedure TStrainer.GlobalFilter(AClass: TClass);
begin
  FFilterClasses.Add(AClass.QualifiedClassName, AClass);
end;

function TStrainer.Invoke(const FilterName: string;
  Args: TArray<TValue>): TValue;
begin
  Result := Args[0];
  var RttiContext := TRttiContext.Create;
  var InvokeArgs := TList<TValue>.Create;
  try
    for var Method in FMethods do
    begin
      if ResolveMethodName(Method.Key) <> ResolveMethodName(FilterName) then
        Continue;
      for var RttiMethod in RttiContext.GetType(Method.Value).GetMethods(Method.Key) do
      begin
        InvokeArgs.Clear;
        if (Length(RttiMethod.GetParameters) > 0) and
          (RttiMethod.GetParameters[0].ParamType.Handle = TypeInfo(ILiquidContext)) then
          InvokeArgs.Add(TValue.From<ILiquidContext>(FContext));
        InvokeArgs.AddRange(Args);
        if Length(RttiMethod.GetParameters) <> InvokeArgs.Count then
          Continue;
        for var I := 0 to Length(RttiMethod.GetParameters) - 1 do
        begin
          var Param := RttiMethod.GetParameters[I];
          var Arg := InvokeArgs[I];
          if Arg.IsEmpty then
            Arg := '';
          if Param.ParamType.TypeKind <> Arg.Kind then
            Exit;
        end;

        var Instance := Method.Value.Create;
        try
          var Output := TValue.Empty;
          Output := RttiMethod.Invoke(Instance, InvokeArgs.ToArray);
          if not Output.IsEmpty then
            Exit(Output);
          Break;
        finally
          Instance.Free;
        end;
      end;
    end;
  finally
    InvokeArgs.Free;
    RttiContext.Free;
  end;
end;

function TStrainer.ResolveMethodName(const MethodName: string): string;
var
  I: Integer;
  Current, Before: Char;
begin
  Result := MethodName;
  I := 2;
  while I <= Length(Result) do
  begin
    Current := Result[I];
    Before := Result[I - 1];
    if Current.IsUpper and (Before <> '_') and Before.IsLower then
    begin
      Insert('_', Result, I);
      Inc(I, 2);
    end
    else
      Inc(I);
  end;
  Result := LowerCase(Result);
end;

{ TGenericFilter }

constructor TGenericFilter.Create(AFilterFunc: TFilterFunc);
begin
  FFunc := AFilterFunc;
end;

function TGenericFilter.Filter(Context: ILiquidContext; const Input: TValue;
  const Args: TArray<TValue>): TValue;
begin
  Result := FFunc(Context, Input, Args);
end;

{ TStandardFilters }

function TStandardFilters.Append(const Input, Value: string): string;
begin
  Result := Input + Value;
end;

function TStandardFilters.Date(Context: ILiquidContext; const Input: TDateTime;
  const Format: string): string;
begin
  Result := FormatDateTime(Format, Input, Context.FormatSettings);
end;

function TStandardFilters.Default(const Input: string; const DefaultValue: string): string;
begin
  if string.IsNullOrEmpty(Input) then
    Result := DefaultValue
  else
    Result := Input;
end;

function TStandardFilters.Downcase(const Input: string): string;
begin
  Result := Input.ToLower;
end;

function TStandardFilters.FormatFloat(Context: ILiquidContext;
  const Input: double; const Format: string): string;
begin
  Result := System.SysUtils.FormatFloat(Format, Input, Context.FormatSettings);
end;

function TStandardFilters.FormatFloat(Context: ILiquidContext;
  const Input: extended; const Format: string): string;
begin
  Result := System.SysUtils.FormatFloat(Format, Input, Context.FormatSettings);
end;

function TStandardFilters.FormatFloat(Context: ILiquidContext;
  const Input: integer; const Format: string): string;
begin
  Result := System.SysUtils.FormatFloat(Format, Input, Context.FormatSettings);
end;

function TStandardFilters.Round(const Input: double; Places: integer): double;
begin
  try
    Result := RoundTo(Input, -1 * Places);
  except
    Result := Input;
  end;
end;

function TStandardFilters.Round(const Input: double): double;
begin
  Result := Round(Input, 0);
end;

function TStandardFilters.Slice(const Input: string; Start: integer): string;
begin
  Result := Slice(Input, Start, 1);
end;

function TStandardFilters.Slice(const Input: string; Start,
  Length: integer): string;
begin
  if Start < 0 then
  begin
    Inc(Start, Input.Length);
    if Start < 0 then
    begin
      Length := Max(0, Length + Start);
      Start := 0;
    end;
  end;
  if (Start + Length > Input.Length) then
    Length := Input.Length - Start;
  Result := Input.Substring(Start, Length);
end;

function TStandardFilters.Upcase(const Input: string): string;
begin
  Result := Input.ToUpper;
end;

initialization
  TStrainer.GlobalFilter(TStandardFilters);

end.
