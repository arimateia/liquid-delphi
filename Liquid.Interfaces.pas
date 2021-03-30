unit Liquid.Interfaces;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Rtti;

type
  TErrorsOutputMode = (Rethrow, Suppress, Display);

  IHash = interface;
  IStrainer = interface;
  IFilter = interface;

  ILiquidContext = interface
  ['{290DFAE7-9685-42B5-A5D8-CC1173411806}']
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

  IHash = interface
  ['{5DB200EB-09E9-4505-A147-CB6F0E17B390}']
    procedure Clear;
    procedure Add(const Key: string; const Value: TValue);
    procedure AddOrSetValue(const Key: string; const Value: TValue);
    function ContainsKey(const Key: string): Boolean;
    function ContainsValue(const Value: TValue): Boolean;
    function GetCount: integer;
    function GetItem(const Key: string): TValue;
    procedure SetItem(const Key: string; const Value: TValue);
    function ToArray: TArray<TPair<string, TValue>>;
    property Items[const Key: string]: TValue read GetItem write SetItem; default;
    property Count: Integer read GetCount;
  end;

  IStrainer = interface
  ['{6F17C663-7B86-4A3C-9102-92BFE67FB984}']
//    procedure AddFilter(const FilterName: string; Filter: IFilter);
//    procedure RegisterFilter(AFilterClass: TClass);
    function Invoke(const FilterName: string; Args: TArray<TValue>): TValue;
  end;

  IRenderable = interface
  ['{7B71A921-EE11-493A-903D-38C3775C6B3B}']
    procedure Render(Context: ILiquidContext; Writer: TTextWriter);
  end;

  IFilter = interface
  ['{DA60855E-8E11-4D37-B52B-295EB60AFF08}']
    function Filter(Context: ILiquidContext; const Input: TValue;
      const Args: TArray<TValue>): TValue;
  end;

implementation

end.
