unit Liquid.Variable;

interface

uses
  System.SysUtils,
  System.Classes, System.Generics.Collections,
  System.RegularExpressions,
  System.Rtti,
  System.TypInfo,

  Liquid.Default,
  Liquid.Interfaces,
  Liquid.Context,
  Liquid.Utils;

type
  TVariable = class
  type
    TFilter = class
    strict private
      FName: string;
      FArguments: TArray<string>;
    public
      constructor Create(AName: string; AArguments: TArray<string>);
      property Name: string read FName;
      property Arguments: TArray<string> read FArguments;
    end;
  strict private
    FFilterParserRegex: TRegEx;
    FFilterArgRegex: TRegEx;
    FQuotedAssignFragmentRegex: TRegEx;
    FFilterSeparatorRegex: TRegEx;
    FFilterNameRegex: TRegEx;
    //
    FName: string;
    FFilters: TList<TFilter>;
    FMarkup: string;
  private
    function RenderInternal(Context: ILiquidContext): TValue; overload;
    procedure RenderInternal(Context: ILiquidContext; Writer: TTextWriter;
      Value: TValue); overload;
  public
    constructor Create(const AMarkup: string);
    destructor Destroy; override;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); overload;
    function Render(Context: ILiquidContext): TValue; overload;
    property Name: string read FName;
    property Filters: TList<TFilter> read FFilters;
  end;

implementation

{ TVariable }

constructor TVariable.Create(const AMarkup: string);
begin
  FFilterParserRegex := R.B(R.Q(
    '(?:%0:s|(?:\s*(?!(?:%0:s))(?:%1:s|\S+)\s*)+)'),
    [LiquidRegexes.FilterSeparator, LiquidRegexes.QuotedFragment]);
  FFilterArgRegex := R.B(R.Q(
    '(?:%0:s|%1:s)\s*(%2:s)'),
    [LiquidRegexes.FilterArgumentSeparator, LiquidRegexes.ArgumentSeparator, LiquidRegexes.QuotedFragment]);
  FQuotedAssignFragmentRegex := R.B(R.Q(
    '\s*(%0:s)(.*)'), [LiquidRegexes.QuotedAssignFragment]);
  FFilterSeparatorRegex := R.B(R.Q(
    '%0:s\s*(.*)'), [LiquidRegexes.FilterSeparator]);
  FFilterNameRegex := R.B(R.Q('\s*(\w+)'), []);

  FFilters := TObjectList<TFilter>.Create;
  FMarkup := AMarkup;
  FName := '';

  var Match := FQuotedAssignFragmentRegex.Match(AMarkup);
  if Match.Success then
  begin
    FName := Match.Groups[1].Value;
    var FilterMatch := FFilterSeparatorRegex.Match(Match.Groups[2].Value);
    if FilterMatch.Success then
    begin
      for var F in R.Scan(FilterMatch.Value, FFilterParserRegex) do
      begin
        var FilterNameMatch := FFilterNameRegex.Match(F);
        if FilterNameMatch.Success then
        begin
          var FilterName := FilterNameMatch.Groups[1].Value;
          var FilterArgs := R.Scan(F, FFilterArgRegex);
          Filters.Add(TFilter.Create(FilterName, FilterArgs));
        end;
      end;
    end;
  end;
end;

destructor TVariable.Destroy;
begin
  FFilters.Free;
  inherited;
end;

procedure TVariable.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  var Value := RenderInternal(Context);
  if not Value.IsEmpty then
    RenderInternal(Context, Writer, Value);
end;

function TVariable.Render(Context: ILiquidContext): TValue;
begin
  Result := RenderInternal(Context);
end;

procedure TVariable.RenderInternal(Context: ILiquidContext; Writer: TTextWriter;
  Value: TValue);
begin
  case Value.Kind of
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
    begin
      Writer.Write(Value.AsString);
    end;

    tkInteger, tkEnumeration:
    begin
      if Value.TypeInfo = TypeInfo(boolean) then
        Writer.Write(BoolToStr(Value.AsBoolean, True).ToLower)
      else
        Writer.Write(Value.AsInteger);
    end;

    tkInt64:
    begin
      Writer.Write(Value.AsInt64);
    end;

    tkFloat:
    begin
      if Value.IsType<TDate> or Value.IsType<TDateTime> then
      begin
        var DateFormatted: string;
        if Frac(Value.AsExtended) > 0 then
          DateFormatted := DateTimeToStr(Value.AsType<TDateTime>, Context.FormatSettings)
        else
          DateFormatted := DateToStr(Value.AsType<TDate>, Context.FormatSettings);
        Writer.Write(DateFormatted);
      end
      else
        Writer.Write(Value.AsExtended);
    end;
  else
    Writer.Write(Value.AsString);
  end;
end;

function TVariable.RenderInternal(Context: ILiquidContext): TValue;
begin
  if Name = '' then
    Exit(TValue.Empty);

  var Value := Context[Name];

  // process filters
  for var Filter in Filters do
  begin
    var FilterArgs := TList<TValue>.Create;
    try
      FilterArgs.Add(Value);
      for var Arg in Filter.Arguments do
      begin
        var ArgResolved := Context[Arg, False];
        FilterArgs.Add(ArgResolved);
      end;
      try
        Value := Context.Strainer.Invoke(Filter.Name, FilterArgs.ToArray);
      except
        on E: EFileNotFoundException do
        begin
          //
//        raise EFileNotFoundException.CreateFmt(
//        'Error - Filter ''%s'' in ''%s'' could not be found.',
//        [Filter.Name, FMarkup.Trim]);
        end;
      end;
    finally
      FilterArgs.Free;
    end;
  end;

  // process IValueTypeConvertible
  // !! not implemented

  Result := Value;
end;

{ TVariable.TFilter }

constructor TVariable.TFilter.Create(AName: string; AArguments: TArray<string>);
begin
  FName := AName;
  FArguments := AArguments;
end;

end.
