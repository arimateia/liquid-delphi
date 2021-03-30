unit Liquid.Utils;

interface

uses
  System.SysUtils, System.Classes,
  System.RegularExpressions,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Rtti, System.TypInfo,
  System.DateUtils,

  Liquid.Default;

type
  R = class
  public
    class function Scan(const Input: string; RegEx: TRegEx): TArray<string>; overload;
    class procedure Scan(const Input: string; const Pattern: string;
      ACallback: TProc<string, string>); overload;
    class function Q(const Regex: string): string;
    class function B(const Format: string; const Args: array of const): TRegEx;
    class function C(const Pattern: string; Options: TRegExOptions = [TRegExOption.roNone]): TRegEx;
  end;

  TSymbol = class
  strict private
    FEvaluationFunction: TFunc<TValue, boolean>;
  public
    constructor Create(AEvaluationFunction: TFunc<TValue, boolean>);
    property EvaluationFunction: TFunc<TValue, boolean> read FEvaluationFunction write FEvaluationFunction;
  end;

  TCompareUtils = class
  public
    class function Comparer(Kind: TTypeKind): IComparer<TValue>;
    class function Compare(Left, Right: TValue): integer;
  end;

  TConverter = class
  private
    class function StringConverter(FromValue: TValue; ToTypeInfo: PTypeInfo;
      ToTypeKind: TTypeKind): TValue;
    class function IntegerConverter(FromValue: TValue; ToTypeInfo: PTypeInfo;
      ToTypeKind: TTypeKind): TValue;
    class function Int64Converter(FromValue: TValue; ToTypeInfo: PTypeInfo;
      ToTypeKind: TTypeKind): TValue;
    class function FloatConverter(FromValue: TValue; ToTypeInfo: PTypeInfo;
      ToTypeKind: TTypeKind): TValue;
  public
    class function ChangeType(FromValue: TValue; ToTypeInfo: PTypeInfo;
      ToTypeKind: TTypeKind): TValue;
    class function StringToRealType(const Value: string; var Output: TValue): boolean;
  end;

  TListHelper = class
  public
    class function TryGetAtIndexReverse(AList: TList<string>; RIndex: integer): string; overload;
    class function TryGetAtIndexReverse(AList: TList<TValue>; RIndex: integer): TValue; overload;
  end;

  ECompareException = class(Exception);
  EUnsupportedType = class(ECompareException);

implementation

{ R }

class function R.B(const Format: string; const Args: array of const): TRegEx;
begin
  Result := C(string.Format(Format, Args));
end;

class function R.C(const Pattern: string; Options: TRegExOptions): TRegEx;
begin
  Result := TRegEx.Create(Pattern);
  Result.IsMatch(string.Empty);
end;

class function R.Q(const Regex: string): string;
begin
  Result := string.Format('(?-mix:%0:s)', [Regex]);
end;

class procedure R.Scan(const Input: string; const Pattern: string;
  ACallback: TProc<string, string>);
begin
  var Matches := TRegEx.Matches(Input, Pattern);
  for var M in Matches do
    ACallback(M.Groups[1].Value, M.Groups[2].Value);
end;

class function R.Scan(const Input: string; RegEx: TRegEx): TArray<string>;
begin
  var L := TList<string>.Create;
  try
    var Matches := RegEx.Matches(Input);
    for var M in Matches do
    begin
      if M.Groups.Count = 2 then
        L.Add(M.Groups[1].Value)
      else
        L.Add(M.Value);
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

{ TSymbol }

constructor TSymbol.Create(AEvaluationFunction: TFunc<TValue, boolean>);
begin
  FEvaluationFunction := AEvaluationFunction;
end;

{ TCompareUtils }

class function TCompareUtils.Compare(Left, Right: TValue): integer;
var
  LocalComparer: IComparer<TValue>;
begin
  if Left.TypeInfo = TypeInfo(TDateTime) then
    LocalComparer := TDelegatedComparer<TValue>.Create(
      function(const Left, Right: TValue): integer
      begin
        Result := CompareDateTime(Left.AsType<TDateTime>,
          Right.AsType<TDateTime>);
      end
    )
  else if Left.IsOrdinal then
    LocalComparer := TDelegatedComparer<TValue>.Create(
      function(const Left, Right: TValue): integer
      begin
        Result := TComparer<Int64>.Default.Compare(
          Left.AsOrdinal, Right.AsOrdinal);
      end
    )
  else
    LocalComparer := Comparer(Left.Kind);
  Result := LocalComparer.Compare(Left, Right);
end;

class function TCompareUtils.Comparer(Kind: TTypeKind): IComparer<TValue>;
begin
  case Kind of
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
    begin
      Result := TDelegatedComparer<TValue>.Create(
        function(const Left, Right: TValue): integer
        begin
          Result := TComparer<string>.Default.Compare(
            Left.AsString, Right.AsString);
        end
      );
    end;

    tkInteger, tkEnumeration:
    begin
      Result := TDelegatedComparer<TValue>.Create(
        function(const Left, Right: TValue): integer
        begin
          Result := TComparer<integer>.Default.Compare(
            Left.AsInteger, Right.AsInteger);
        end
      );
    end;

    tkInt64:
    begin
      Result := TDelegatedComparer<TValue>.Create(
        function(const Left, Right: TValue): integer
        begin
          Result := TComparer<int64>.Default.Compare(
            Left.AsInt64, Right.AsInt64);
        end
      );
    end;

    tkFloat:
    begin
      Result := TDelegatedComparer<TValue>.Create(
        function(const Left, Right: TValue): integer
        begin
          Result := TComparer<double>.Default.Compare(
            Left.AsExtended, Right.AsExtended);
        end
      );
    end;
  else
    raise EUnsupportedType.CreateFmt('Unsupported type: %s',
      [TRttiEnumerationType.GetName(Kind)]);
  end;
end;

{ TListHelper }

class function TListHelper.TryGetAtIndexReverse(AList: TList<TValue>;
  RIndex: integer): TValue;
begin
  if (AList <> nil) and (AList.Count > RIndex) and (RIndex >= 0) then
    Exit(AList[AList.Count - 1 - Rindex]);
  Result := TValue.Empty;
end;

class function TListHelper.TryGetAtIndexReverse(AList: TList<string>;
  RIndex: integer): string;
begin
  if (AList <> nil) and (AList.Count > RIndex) and (RIndex >= 0) then
    Exit(AList[AList.Count - 1 - Rindex]);
  Result := '';
end;

{ TConverter }

class function TConverter.StringToRealType(const Value: string;
  var Output: TValue): boolean;
begin
  if Value.Equals('') or Value.Equals('nil') or Value.Equals('null') then
  begin
    Output := TValue.Empty;
    Exit(True);
  end;
  if Value.Equals('true') then
  begin
    Output := True;
    Exit(True);
  end;
  if Value.Equals('false') then
  begin
    Output := False;
    Exit(True);
  end;
  if Value.Equals('blank') or Value.Equals('empty') then
  begin
    Output := '';
    Exit(True);
  end;

  var Match := LiquidRegexes.SingleQuotedRegex.Match(Value);
  if Match.Success then
  begin
    Output := Match.Groups[1].Value;
    Exit(True);
  end;

  Match := LiquidRegexes.DoubleQuotedRegex.Match(Value);
  if Match.Success then
  begin
    Output := Match.Groups[1].Value;
    Exit(True);
  end;

  Match := LiquidRegexes.IntegerRegex.Match(Value);
  if Match.Success then
  begin
    try
      Output := StrToInt(Match.Groups[1].Value);
      Exit(True);
    except
      on E: EConvertError do
      begin
        Output := StrToInt64(Match.Groups[1].Value);
        Exit(True);
      end;
    end;
  end;

//  Match := LiquidRegexes.RangeRegex.Match(Value);
//  if Match.Success then
//  begin
//    raise Exception.Create('not implemented');
//  end;

  Match := LiquidRegexes.NumericRegex.Match(Value);
  if Match.Success then
  begin
    var Number := Match.Groups[1].Value;
    var DoubleNumber: double;
    if TryStrToFloat(Number, DoubleNumber, FormatSettings) then
    begin
      Output := DoubleNumber;
      Exit(True);
    end;

    var ExtendedNumber: double;
    if TryStrToFloat(Number, ExtendedNumber, FormatSettings) then
    begin
      Output := ExtendedNumber;
      Exit(True);
    end;
  end;

  Result := False;
end;

class function TConverter.FloatConverter(FromValue: TValue;
  ToTypeInfo: PTypeInfo; ToTypeKind: TTypeKind): TValue;
begin
  if ToTypeInfo = TypeInfo(boolean) then
  begin
    if FromValue.IsEmpty then
      Exit(False);
    Exit(True);
  end;
  Result := FromValue;
end;

class function TConverter.Int64Converter(FromValue: TValue;
  ToTypeInfo: PTypeInfo; ToTypeKind: TTypeKind): TValue;
begin
  if ToTypeInfo = TypeInfo(boolean) then
  begin
    if FromValue.IsEmpty then
      Exit(False);
    Exit(True);
  end;

  case ToTypeKind of
    tkFloat:
    begin
      Result := FromValue.AsExtended;
    end;
  else
    Result := FromValue;
  end;
end;

class function TConverter.IntegerConverter(FromValue: TValue;
  ToTypeInfo: PTypeInfo; ToTypeKind: TTypeKind): TValue;
begin
  if ToTypeInfo = TypeInfo(boolean) then
  begin
    if FromValue.IsEmpty then
      Exit(False);
    Exit(True);
  end;

  case ToTypeKind of
    tkInt64:
    begin
      Result := FromValue.AsInt64;
    end;

    tkFloat:
    begin
      Result := FromValue.AsExtended;
    end;
  else
    Result := FromValue;
  end;
end;

class function TConverter.StringConverter(FromValue: TValue;
  ToTypeInfo: PTypeInfo; ToTypeKind: TTypeKind): TValue;
begin
  if ToTypeInfo = TypeInfo(boolean) then
  begin
    if FromValue.IsEmpty or string.IsNullOrEmpty(FromValue.AsString) then
      Exit(False);
    Exit(True);
  end;

  Result := FromValue;
end;

class function TConverter.ChangeType(FromValue: TValue;
  ToTypeInfo: PTypeInfo; ToTypeKind: TTypeKind): TValue;
begin
  case FromValue.Kind of
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
    begin
      Result := StringConverter(FromValue, ToTypeInfo, ToTypeKind);
    end;

    tkInteger, tkEnumeration:
    begin
      Result := IntegerConverter(FromValue, ToTypeInfo, ToTypeKind);
    end;

    tkInt64:
    begin
      Result := Int64Converter(FromValue, ToTypeInfo, ToTypeKind);
    end;

    tkFloat:
    begin
      Result := FloatConverter(FromValue, ToTypeInfo, ToTypeKind);
    end;
  else
    Result := FromValue;
  end;
end;

end.
