unit Liquid.Filters;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti, System.TypInfo,

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
      if Method.Key.ToLower = FilterName.ToLower then
      begin
        var RttiMethod := RttiContext.GetType(Method.Value).GetMethod(Method.Key);
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
            Result := Output;
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

function TStandardFilters.Upcase(const Input: string): string;
begin
  Result := Input.ToUpper;
end;

initialization
  TStrainer.GlobalFilter(TStandardFilters);

end.
