unit Liquid.Condition;

interface

uses
  System.SysUtils,
  System.Classes, System.Generics.Collections,
  System.Generics.Defaults,
  System.RegularExpressions,
  System.Rtti,
  System.TypInfo,

  Liquid.Default,
  Liquid.Interfaces,
  Liquid.Context,
  Liquid.Variable,
  Liquid.Exceptions,
  Liquid.Hash,
  Liquid.Utils,
  Liquid.Tag;

type
  IConditionOperatorDelegate = interface
  ['{102E2511-5223-4CF4-9275-25EE917307F0}']
    function Evaluate(const Left, Right: TValue): boolean;
  end;

  TCondition = class
  strict private
    class var
      FOperators: TDictionary<string, IConditionOperatorDelegate>;
  private
    FChildRelation: string;
    FChildCondition: TCondition;
    FLeft: string;
    FOperator: string;
    FRight: string;
    FAttachment: INodeList;
  private
    class function InterpretCondition(const ALeft: string; const ARight: string;
      const AOperator: string; AContext: ILiquidContext): boolean;
  public
    class constructor Create;
    class destructor Destroy;
    class function Operators: TDictionary<string, IConditionOperatorDelegate>;
    class function Any(Enumerable: IEnumerable<TValue>; Condition: TFunc<TValue, boolean>): boolean;
  public
    constructor Create; overload;
    constructor Create(ASyntaxMatch: TMatch); overload;
    constructor Create(const ALeft: string; const AOperator: string;
      const ARight: string); overload;
    destructor Destroy; override;
    function IsElse: boolean; virtual;
    function Evaluate(Context: ILiquidContext; FormatSettings: TFormatSettings): boolean; virtual;
    procedure _Or(Condition: TCondition);
    procedure _And(Condition: TCondition);
    function Attach(Attachment: INodeList): INodeList;
    function ToString: string; override;
    property Left: string read FLeft write FLeft;
    property _Operator: string read FOperator write FOperator;
    property Right: string read FRight write FRight;
    property Attachment: INodeList read FAttachment;
  end;

  TElseCondition = class(TCondition)
  public
    function IsElse: boolean; override;
    function Evaluate(Context: ILiquidContext; FormatSettings: TFormatSettings): boolean; override;
  end;

  TConditionOperatorDelegate = class(TInterfacedObject, IConditionOperatorDelegate)
  strict private
    class function Compare(const Left, Right: IHash): boolean; overload;
  protected
    class function EqualVariables(const Left, Right: TValue): boolean;
    class function Compare(const Left, Right: TValue): integer; overload;
    class function Compare(const Left, Right: TValue; var Value: integer): boolean; overload;
  public
    function Evaluate(const Left, Right: TValue): boolean; virtual; abstract;
  end;

  TEqualOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TNotEqualOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TGreaterThanOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TGreaterThanEqualOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TLessThanOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TLessThanEqualOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TContainsOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TStartsWithOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  TEndsWithOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  THasKeyOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

  THasValueOperatorDelegate = class(TConditionOperatorDelegate)
  public
    function Evaluate(const Left, Right: TValue): boolean; override;
  end;

implementation

{ TCondition }

class function TCondition.Any(Enumerable: IEnumerable<TValue>;
  Condition: TFunc<TValue, boolean>): boolean;
begin
  for var Value in Enumerable do
    if Condition(Value) then
      Exit(True);
  Result := False;
end;

function TCondition.Attach(Attachment: INodeList): INodeList;
begin
  FAttachment := Attachment;
  Result := FAttachment;
end;

class constructor TCondition.Create;
begin
  TCondition.FOperators := TDictionary<string, IConditionOperatorDelegate>.Create;
  var Operators := TCondition.Operators;

  Operators.Add('==', TEqualOperatorDelegate.Create);
  Operators.Add('!=', TNotEqualOperatorDelegate.Create);
  Operators.Add('<>', TNotEqualOperatorDelegate.Create);
  Operators.Add('>', TGreaterThanOperatorDelegate.Create);
  Operators.Add('>=', TGreaterThanEqualOperatorDelegate.Create);
  Operators.Add('<', TLessThanOperatorDelegate.Create);
  Operators.Add('<=', TLessThanEqualOperatorDelegate.Create);
  Operators.Add('contains', TContainsOperatorDelegate.Create);
  Operators.Add('startsWith', TStartsWithOperatorDelegate.Create);
  Operators.Add('endsWith', TEndsWithOperatorDelegate.Create);
  Operators.Add('hasKey', THasKeyOperatorDelegate.Create);
  Operators.Add('hasValue', THasValueOperatorDelegate.Create);
end;

constructor TCondition.Create(const ALeft, AOperator, ARight: string);
begin
  Create;
  FLeft := ALeft;
  FOperator := AOperator;
  FRight := ARight;
end;

destructor TCondition.Destroy;
begin
  FChildCondition.Free;
end;

constructor TCondition.Create(ASyntaxMatch: TMatch);
begin
  if ASyntaxMatch.Groups.Count = 4 then
  begin
    Create(
      ASyntaxMatch.Groups[1].Value,
      ASyntaxMatch.Groups[2].Value,
      ASyntaxMatch.Groups[3].Value
    );
  end
  else
    Create(ASyntaxMatch.Groups[1].Value, '', '');
end;

class destructor TCondition.Destroy;
begin
  TCondition.FOperators.Free;
end;

constructor TCondition.Create;
begin
  FAttachment := TNodeList.Create;
end;

function TCondition.Evaluate(Context: ILiquidContext;
  FormatSettings: TFormatSettings): boolean;
begin
  var OwnContext := False;
  if Context = nil then
  begin
    Context := TLiquidContext.Create(FormatSettings);
    OwnContext := True;
  end;
  try
    Result := InterpretCondition(Left, Right, _Operator, Context);
    if FChildRelation = 'or' then
      Result := Result or FChildCondition.Evaluate(Context, FormatSettings)
    else if FChildRelation = 'and' then
      Result := Result and FChildCondition.Evaluate(Context, FormatSettings);
  finally
    if OwnContext then
      Context := nil;
  end;
end;

class function TCondition.InterpretCondition(const ALeft, ARight,
  AOperator: string; AContext: ILiquidContext): boolean;
begin
  // If the operator is empty this means that the decision statement is just
  // a single variable. We can just poll this variable from the context and
  // return this as the result.
  if string.IsNullOrEmpty(AOperator) then
  begin
    var Value := AContext[ALeft, False];
    Exit((not Value.IsEmpty) and
      ((not Value.IsType<boolean>) or (Value.AsBoolean)));
  end;

  var LeftValue := AContext[ALeft];
  var RightValue := AContext[ARight];

  var OperatorKey: string := '';
  for var Opk in Operators.Keys do
    if Opk.Equals(AOperator) or Opk.ToLowerInvariant.Equals(AOperator) then
    begin
      OperatorKey := Opk;
      Break;
    end;
  if OperatorKey.IsEmpty then
    raise EArgumentException.CreateFmt('Unknown operator %s', [AOperator]);
  Result := Operators[OperatorKey].Evaluate(LeftValue, RightValue);
end;

function TCondition.IsElse: boolean;
begin
  Result := False;
end;

class function TCondition.Operators: TDictionary<string, IConditionOperatorDelegate>;
begin
  Result := FOperators;
end;

function TCondition.ToString: string;
begin
  Result := Format('<Condition %0:s %1:s %2:s>', [Left, _Operator, Right]);
end;

procedure TCondition._And(Condition: TCondition);
begin
  FChildRelation := 'and';
  if FChildCondition <> nil then
    FChildCondition.Free;
  FChildCondition := Condition;
end;

procedure TCondition._Or(Condition: TCondition);
begin
  FChildRelation := 'or';
  if FChildCondition <> nil then
    FChildCondition.Free;
  FChildCondition := Condition;
end;

{ TElseCondition }

function TElseCondition.Evaluate(Context: ILiquidContext;
  FormatSettings: TFormatSettings): boolean;
begin
  Result := True;
end;

function TElseCondition.IsElse: boolean;
begin
  Result := True;
end;

//class function TConditionComparer.EqualVariables(ALeft,
//  ARight: TValue): boolean;
//begin
//  if ALeft.IsType<TSymbol>(False) then
//    Exit(ALeft.AsType<TSymbol>.EvaluationFunction(ARight));
//  if ARight.IsType<TSymbol>(False) then
//    Exit(ARight.AsType<TSymbol>.EvaluationFunction(ALeft));
//  Result := TCompareUtils.Compare(ALeft, ARight) = 0;
//end;

{ TConditionOperatorDelegate }

class function TConditionOperatorDelegate.Compare(const Left, Right: TValue;
  var Value: integer): boolean;
begin
//  if Left.IsEmpty then
//  begin
//    Value := TDelegatedComparer<TValue>.Default.Compare(Left, Right);
//    Exit(True);
//  end;
  if Right.IsEmpty or Left.IsEmpty then
    Exit(False);
  if Left.TypeInfo = Right.TypeInfo then
  begin
    Value := TCompareUtils.Compare(Left, Right);
    Exit(True);
  end;

  var RightChanged := TConverter.ChangeType(Right, Left.TypeInfo, Left.Kind);
  if (Left.TypeInfo = RightChanged.TypeInfo) or (Left.Kind = RightChanged.Kind) then
  begin
    Value := TCompareUtils.Compare(Left, RightChanged);
    Exit(True);
  end;
  Result := False;
end;

class function TConditionOperatorDelegate.EqualVariables(const Left,
  Right: TValue): boolean;
begin
  if Left.IsEmpty and Right.IsEmpty then
    Exit(True);
  if Left.IsEmpty or Right.IsEmpty then
    Exit(False);
//  if Left.TypeInfo <> Right.TypeInfo then
//    Exit(False);
  if Left.IsType<TArray<TValue>> and Right.IsType<TArray<TValue>> then
  begin
    var LeftArray := Left.AsType<TArray<TValue>>;
    var RightArray := Right.AsType<TArray<TValue>>;
    if Length(LeftArray) <> Length(RightArray) then
      Exit(False);
    for var I := 0 to Length(LeftArray) - 1 do
      if not EqualVariables(LeftArray[I], RightArray[I]) then
        Exit(False);
    Result := True;
  end
  else if Left.IsType<IHash> and Right.IsType<IHash> then
  begin
    Result := Compare(Left.AsType<IHash>, Right.AsType<IHash>);
  end
  else
  begin
    var Res: integer;
    if Compare(Left, Right, Res) then
      Result := Res = 0
    else
      Result := False;
  end;
end;

class function TConditionOperatorDelegate.Compare(const Left, Right: TValue): integer;
begin
  if not Compare(Left, Right, Result) then
    raise ECompareException.Create('Unrealized operation');
end;

class function TConditionOperatorDelegate.Compare(const Left, Right: IHash): boolean;
begin
  if Left.Count <> Right.Count then
    Exit(False);
  for var LeftPair in Left.ToArray do
  begin
    if not Right.ContainsKey(LeftPair.Key) then
      Exit(False);
    if not EqualVariables(LeftPair.Value, Right[LeftPair.Key]) then
      Exit(False);
  end;
  Result := True;
end;

{ TEqualOperatorDelegate }

function TEqualOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  Result := EqualVariables(Left, Right);
end;

{ TNotEqualOperatorDelegate }

function TNotEqualOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  Result := not EqualVariables(Left, Right);
end;

{ TGreaterThanOperatorDelegate }

function TGreaterThanOperatorDelegate.Evaluate(const Left,
  Right: TValue): boolean;
begin
  var Value: integer;
  if Compare(Left, Right, Value) then
    Result := Value > 0
  else
    Result := False;
end;

{ TGreaterThanEqualOperatorDelegate }

function TGreaterThanEqualOperatorDelegate.Evaluate(const Left,
  Right: TValue): boolean;
begin
  var Value: integer;
  if Compare(Left, Right, Value) then
    Result := Value >= 0
  else
    Result := False;
end;

{ TLessThanOperatorDelegate }

function TLessThanOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  var Value: integer;
  if Compare(Left, Right, Value) then
    Result := Value < 0
  else
    Result := False;
end;

{ TLessThanEqualOperatorDelegate }

function TLessThanEqualOperatorDelegate.Evaluate(const Left,
  Right: TValue): boolean;
begin
  var Value: integer;
  if Compare(Left, Right, Value) then
    Result := Value <= 0
  else
    Result := False;
end;

{ TContainsOperatorDelegate }

function TContainsOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  if Left.IsEmpty then
    Exit(False);
  if Left.IsType<string> then
  begin
    if Right.IsType<string> then
      Exit(Left.AsString.Contains(Right.AsString));
  end
  else if Left.IsArray then
  begin
    for var Item in Left.AsType<TArray<TValue>> do
    begin
      if EqualVariables(Item, Right) then
        Exit(True);
    end;
  end;
  Result := False;
end;

{ TStartsWithOperatorDelegate }

function TStartsWithOperatorDelegate.Evaluate(const Left,
  Right: TValue): boolean;
begin
  if Left.IsType<string> then
  begin
    if Right.IsType<string> then
      Exit(Left.AsString.StartsWith(Right.AsString));
  end
  else if Left.IsArray then
  begin
    var List := Left.AsType<TArray<TValue>>;
    if Length(List) = 0 then
      Exit(False);
    var First := List[0];
    if EqualVariables(First, Right) then
      Exit(True);
  end;
  Result := False;
end;

{ TEndsWithOperatorDelegate }

function TEndsWithOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  if Left.IsType<string> then
  begin
    if Right.IsType<string> then
      Exit(Left.AsString.EndsWith(Right.AsString));
  end
  else if Left.IsArray then
  begin
    var List := Left.AsType<TArray<TValue>>;
    if Length(List) = 0 then
      Exit(False);
    var ArrayValue := Left.AsType<TArray<TValue>>;
    var Last := ArrayValue[Length(ArrayValue) - 1];
    if EqualVariables(Last, Right) then
      Exit(True);
  end;
  Result := False;
end;

{ THasKeyOperatorDelegate }

function THasKeyOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  if Left.IsEmpty then
    Exit(False);
  if not Right.IsType<string> then
    Exit(False);
  if Left.IsType<IHash> then
    Exit(Left.AsType<IHash>.ContainsKey(Right.AsString));
  Result := False;
end;

{ THasValueOperatorDelegate }

function THasValueOperatorDelegate.Evaluate(const Left, Right: TValue): boolean;
begin
  if Left.IsEmpty then
    Exit(False);

  if Left.IsType<IHash> then
  begin
    for var Pair in Left.AsType<IHash>.ToArray do
      if EqualVariables(Pair.Value, Right) then
        Exit(True);
  end;
  Result := False;
end;

end.
