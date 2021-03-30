unit Liquid.Tag;

interface

uses
  System.SysUtils,
  System.Classes, System.Generics.Collections,
  System.RegularExpressions,
  System.Rtti,

  Liquid.Interfaces,
  Liquid.Default,
  Liquid.Context,
  Liquid.Variable,
  Liquid.Exceptions,
  Liquid.Utils;

type
  INodeList = interface;

  TTag = class//(TInterfacedObject, IRenderable)
  strict private
    FTagName: string;
    FMarkup: string;
    FNodeList: INodeList;
  protected
    procedure SetNodeList(ANodeList: INodeList);
    procedure Parse(ATokens: TList<string>); virtual;
  public
    constructor Create;
    procedure Initialize(const ATagName: string; const AMarkup: string;
      ATokens: TList<string>); virtual;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); virtual;
    procedure AssertTagRulesViolation(RootNodeList: INodeList); virtual;
    function Name: string;
    property NodeList: INodeList read FNodeList;
    property TagName: string read FTagName;
    property Markup: string read FMarkup;
  end;

  INodeList = interface
  ['{9D108281-A5D3-403D-BDB8-22AE9FF1A151}']
    procedure Add(Value: TValue);
    procedure Clear;
    function GetEnumerator: TEnumerator<TValue>;
  end;

  TNodeList = class(TInterfacedObject, INodeList)
  strict private
    FValues: TList<TValue>;
    FObjects: TList<TObject>;
  public
    function GetEnumerator: TEnumerator<TValue>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Value: TValue);
    procedure Clear;
  end;

  TTagClass = class of TTag;

  ITagFactory = interface
  ['{769EA21E-363D-4CD3-9581-4B82BA7CA77C}']
    function GetTagName: string;
    function CreateTag: TTag;
    property TagName: string read GetTagName;
  end;

  TRttiTagFactory = class(TInterfacedObject, ITagFactory)
  strict private
    FTagName: string;
    FTagClass: TTagClass;
  private
    function GetTagName: string;
  public
    constructor Create(ATagClass: TTagClass; const ATagName: string);
    function CreateTag: TTag;
    property TagName: string read GetTagName;
  end;

implementation

{ TTag }

procedure TTag.AssertTagRulesViolation(RootNodeList: INodeList);
begin
end;

constructor TTag.Create;
begin
  FNodeList := TNodeList.Create;
end;

procedure TTag.Initialize(const ATagName, AMarkup: string;
  ATokens: TList<string>);
begin
  FTagName := ATagName;
  FMarkup := AMarkup;
  Parse(ATokens);
end;

function TTag.Name: string;
begin
  Result := Self.ClassName.ToLower;
end;

procedure TTag.Parse(ATokens: TList<string>);
begin
end;

procedure TTag.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
end;

procedure TTag.SetNodeList(ANodeList: INodeList);
begin
  FNodeList := ANodeList;
end;

{ TRttiTagFactory }

constructor TRttiTagFactory.Create(ATagClass: TTagClass; const ATagName: string);
begin
  FTagClass := ATagClass;
  FTagName := ATagName;
end;

function TRttiTagFactory.CreateTag: TTag;
var
  C: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  C := TRttiContext.Create;
  try
    RttiType := C.GetType(FTagClass);
    for Method in RttiType.GetMethods do
    begin
      if Method.IsConstructor and (Length(Method.GetParameters) = 0) then
        Exit(Method.Invoke(FTagClass, []).AsType<TTag>);
    end;
    Result := nil;
  finally
    C.Free;
  end;
end;

function TRttiTagFactory.GetTagName: string;
begin
  Result := FTagName;
end;

{ TNodeList }

procedure TNodeList.Add(Value: TValue);
begin
  FValues.Add(Value);
  if Value.IsObject then
    FObjects.Add(Value.AsObject);
end;

procedure TNodeList.Clear;
begin
  FValues.Clear;
  FObjects.Clear;
end;

constructor TNodeList.Create;
begin
  FValues := TList<TValue>.Create;
  FObjects := TList<TObject>.Create;
end;

destructor TNodeList.Destroy;
begin
  FValues.Free;
  FObjects.Free;
  inherited;
end;

function TNodeList.GetEnumerator: TEnumerator<TValue>;
begin
  Result := FValues.GetEnumerator;
end;

end.
