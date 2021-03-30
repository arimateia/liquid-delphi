unit Liquid.Hash;

interface

uses
  System.SysUtils, System.Rtti, System.JSON, System.DateUtils,
  System.RegularExpressions,
  System.Generics.Collections,

  Liquid.Interfaces;

type
  THash = class(TInterfacedObject, IHash)
  strict private
    FHash: TDictionary<string, TValue>;
    FNestedHashs: TList<IHash>;
    FLambda: TFunc<IHash, string, TValue>;
    FDefaultValue: TValue;
  private
    function GetItem(const Key: string): TValue;
    procedure SetItem(const Key: string; const Value: TValue);
    function GetCount: integer;
    procedure AddNestedHash(Value: TValue);
  public
    class function FromJson(const Json: string): IHash;
  public
    constructor Create; overload;
    constructor Create(ALambda: TFunc<IHash, string, TValue>); overload;
    constructor Create(ADefaultValue: TValue); overload;
    destructor Destroy; override;

    procedure Clear;
    procedure Add(const Key: string; const Value: TValue);
    procedure AddOrSetValue(const Key: string; const Value: TValue);
    function ContainsKey(const Key: string): Boolean;
    function ContainsValue(const Value: TValue): Boolean;
    function ToArray: TArray<TPair<string, TValue>>;
    property Items[const Key: string]: TValue read GetItem write SetItem; default;
    property Count: Integer read GetCount;
  end;

  IHashFactory = interface
  ['{4822E81F-3C1F-4093-A23E-C91EED3FDE2A}']
    function CreateHash: IHash;
  end;

  THashJsonFactory = class(TInterfacedObject, IHashFactory)
  strict private
    FJson: string;
    FLevelCount: integer;
    function GetHash(JValue: TJSONValue): IHash; overload;
    function GetHash(JObject: TJSONObject): IHash; overload;
    //
    function GetElementValue(JValue: TJSONValue): TValue;
    function GetStringValue(JString: TJSONString): TValue;
    function GetNumberValue(JNumber: TJSONNumber): TValue;
    function GetArrayValue(JArray: TJSONArray): TValue;
  public
    constructor Create(const AJson: string);
    function CreateHash: IHash;
  end;

implementation

{ THash }

procedure THash.Add(const Key: string; const Value: TValue);
begin
  AddNestedHash(Value);
  FHash.Add(Key, Value);
end;

procedure THash.AddNestedHash(Value: TValue);
begin
  if Value.IsType<IHash> then
    FNestedHashs.Add(Value.AsType<IHash>)
  else if Value.IsType<TArray<TValue>> then
  begin
    for var E in Value.AsType<TArray<TValue>> do
      if E.IsType<IHash> then
        FNestedHashs.Add(E.AsType<IHash>);
  end;
end;

procedure THash.AddOrSetValue(const Key: string; const Value: TValue);
begin
  AddNestedHash(Value);
  FHash.AddOrSetValue(Key, Value);
end;

procedure THash.Clear;
begin
  FHash.Clear;
end;

function THash.ContainsKey(const Key: string): Boolean;
begin
  Result := FHash.ContainsKey(Key);
end;

function THash.ContainsValue(const Value: TValue): Boolean;
begin
  Result := FHash.ContainsValue(Value);
end;

constructor THash.Create(ADefaultValue: TValue);
begin
  Create;
  FDefaultValue := ADefaultValue;
end;

constructor THash.Create(ALambda: TFunc<IHash, string, TValue>);
begin
  Create;
  FLambda := ALambda;
end;

constructor THash.Create;
begin
  FHash := TDictionary<string, TValue>.Create;
  FNestedHashs := TList<IHash>.Create;
end;

destructor THash.Destroy;
begin
  FNestedHashs.Free;
  FHash.Free;
  inherited;
end;

class function THash.FromJson(const Json: string): IHash;
begin
  var Factory: IHashFactory := THashJsonFactory.Create(Json);
  Result := Factory.CreateHash;
end;

function THash.GetCount: integer;
begin
  Result := FHash.Count;
end;

function THash.GetItem(const Key: string): TValue;
begin
  if FHash.ContainsKey(Key) then
    Exit(FHash[Key]);
  if Assigned(FLambda) then
    Exit(FLambda(Self, Key));
  if not FDefaultValue.IsEmpty then
    Exit(FDefaultValue);
  Result := TValue.Empty;
end;

procedure THash.SetItem(const Key: string; const Value: TValue);
begin
  AddOrSetValue(Key, Value);
end;

function THash.ToArray: TArray<TPair<string, TValue>>;
begin
  Result := FHash.ToArray;
end;

{ THashJsonFactory }

constructor THashJsonFactory.Create(const AJson: string);
begin
  FJson := AJson;
end;

function THashJsonFactory.CreateHash: IHash;
begin
  FLevelCount := 0;
  var JValue := TJSONObject.ParseJSONValue(FJson);
  try
    Result := GetHash(JValue);
  finally
    JValue.Free;
  end;
end;

function THashJsonFactory.GetHash(JValue: TJSONValue): IHash;
begin
  if JValue is TJSONObject then
    Result := GetHash(TJSONObject(JValue))
  else
    raise EArgumentException.Create('JSON value conversion to THash is not possible');
end;

function THashJsonFactory.GetArrayValue(JArray: TJSONArray): TValue;
begin
  var ArrayList := TList<TValue>.Create;
  try
    for var Item in JArray do
      ArrayList.Add(GetElementValue(Item));
    Result := TValue.From<TArray<TValue>>(ArrayList.ToArray);
  finally
    ArrayList.Free;
  end;
end;

function THashJsonFactory.GetElementValue(JValue: TJSONValue): TValue;
begin
  if JValue is TJSONNumber then
    Result := GetNumberValue(TJSONNumber(JValue))
  else if JValue is TJSONString then
    Result := GetStringValue(TJSONString(JValue))
  else if JValue is TJSONBool then
    Result := TJSONBool(JValue).AsBoolean
  else if JValue is TJSONObject then
    Result := TValue.From<IHash>(GetHash(TJSONObject(JValue)))
  else if JValue is TJSONArray then
    Result := GetArrayValue(TJSONArray(JValue))
  else if JValue is TJSONNull then
    Result := TValue.Empty
  else
    raise EArgumentException.Create('JSON value conversion to TValue is not possible');
end;

function THashJsonFactory.GetHash(JObject: TJSONObject): IHash;
begin
  Result := THash.Create;
  for var Member in JObject do
    Result.Add(Member.JsonString.Value, GetElementValue(Member.JsonValue));
end;

function THashJsonFactory.GetStringValue(JString: TJSONString): TValue;
begin
  if JString.Value.Trim = '' then
    Exit(JString.Value);
  var DateTime: TDateTime;
  if TryISO8601ToDate(JString.Value, DateTime) then
    Exit(DateTime);
  Result := JString.Value
end;

function THashJsonFactory.GetNumberValue(JNumber: TJSONNumber): TValue;
begin
  if Pos('.', JNumber.ToString) > 0 then
    Result := JNumber.AsDouble
  else
  begin
    var Int64Value := JNumber.AsInt64;
    var IntValue := JNumber.AsInt;
    if IntValue = Int64Value then
      Result := IntValue
    else
      Result := Int64Value;
  end;
end;

end.
