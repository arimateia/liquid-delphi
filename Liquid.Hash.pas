unit Liquid.Hash;

interface

uses
  System.SysUtils, System.Rtti,
  System.RegularExpressions,
  System.Generics.Collections,

  Bcl.Json,
  Bcl.Json.Classes,
  Bcl.Utils,

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
    function GetHash(JElement: TJElement): IHash; overload;
    function GetHash(JObject: TJObject): IHash; overload;
    //
    function GetElementValue(JElement: TJElement): TValue;
    function GetPrimitiveValue(JPrimitive: TJPrimitive): TValue;
    function GetArrayValue(JArray: TJArray): TValue;
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
  var JElement := TJson.Deserialize<TJElement>(FJson);
  try
    Result := GetHash(JElement);
  finally
    JElement.Free;
  end;
end;

function THashJsonFactory.GetHash(JElement: TJElement): IHash;
begin
  if JElement.IsObject then
    Result := GetHash(JElement.AsObject)
  else
    raise EArgumentException.Create('JElement conversion to THash is not possible');
end;

function THashJsonFactory.GetArrayValue(JArray: TJArray): TValue;
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

function THashJsonFactory.GetElementValue(JElement: TJElement): TValue;
begin
  if JElement.IsPrimitive then
    Result := GetPrimitiveValue(JElement.AsPrimitive)
  else if JElement.IsObject then
    Result := TValue.From<IHash>(GetHash(JElement.AsObject))
  else if JElement.IsArray then
    Result := GetArrayValue(JElement.AsArray)
  else if JElement.IsNull then
    Result := TValue.Empty
  else
    raise EArgumentException.Create('JElement conversion to TValue is not possible');
end;

function THashJsonFactory.GetHash(JObject: TJObject): IHash;
begin
  Result := THash.Create;
  for var Member in JObject do
    Result.Add(Member.Name, GetElementValue(Member.Value));
end;

function THashJsonFactory.GetPrimitiveValue(JPrimitive: TJPrimitive): TValue;
begin
  if JPrimitive.IsBoolean then
    Result := JPrimitive.AsBoolean
  else if JPrimitive.IsString then
  begin
    if JPrimitive.AsString.Trim = '' then
      Exit(JPrimitive.AsString);
    var Date: TDate;
    if TBclUtils.TryISOToDate(JPrimitive.AsString, Date) then
      Exit(Date);
    var DateTime: TDateTime;
    if TBclUtils.TryISOToDateTime(JPrimitive.AsString, DateTime) then
      Exit(DateTime);
    Result := JPrimitive.AsString;
  end
  else if JPrimitive.IsInteger then
    Result := JPrimitive.AsInteger
  else if JPrimitive.IsDouble then
    Result := JPrimitive.AsDouble
  else if JPrimitive.IsInt64 then
    Result := JPrimitive.AsInt64
  else
    raise EArgumentException.Create('Primitive value not supported');
end;

end.
