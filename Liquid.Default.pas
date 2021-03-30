unit Liquid.Default;

interface

uses
  System.SysUtils, System.Rtti,
  System.RegularExpressions,
  System.Generics.Collections;

type
  TLiquid = class
  strict private
    FFilterSeparator: string;
    FArgumentSeparator: string;
    FFilterArgumentSeparator: string;
    FVariableAttributeSeparator: string;
    FTagStart: string;
    FTagEnd: string;
    FVariableSignature: string;
    FVariableSegment: string;
    FVariableStart: string;
    FVariableEnd: string;
    FVariableIncompleteEnd: string;
    FQuotedString: string;
    FQuotedFragment: string;
    FQuotedAssignFragment: string;
    FStrictQuotedFragment: string;
    FFirstFilterArgument: string;
    FOtherFilterArgument: string;
    FSpacelessFilter: string;
    FExpression: string;
    FTagAttributes: string;
    FAnyStartingTag: string;
    FPartialTemplateParser: string;
    FTemplateParser: string;
    FVariableParser: string;
    FLiteralShorthand: string;
    FCommentShorthand: string;

    // regexes
    FSingleQuotedRegex: TRegEx;
    FDoubleQuotedRegex: TRegEx;
    FIntegerRegex: TRegEx;
    FRangeRegex: TRegEx;
    FNumericRegex: TRegEx;
    FSquareBracketedRegex: TRegEx;
    FVariableParserRegex: TRegEx;
  private
    function GetAnyStartingTag: string;
    function GetArgumentSeparator: string;
    function GetCommentShorthand: string;
    function GetExpression: string;
    function GetFilterArgumentSeparator: string;
    function GetFilterSeparator: string;
    function GetFirstFilterArgument: string;
    function GetLiteralShorthand: string;
    function GetOtherFilterArgument: string;
    function GetPartialTemplateParser: string;
    function GetQuotedAssignFragment: string;
    function GetQuotedFragment: string;
    function GetQuotedString: string;
    function GetSpacelessFilter: string;
    function GetStrictQuotedFragment: string;
    function GetTagAttributes: string;
    function GetTagEnd: string;
    function GetTagStart: string;
    function GetTemplateParser: string;
    function GetVariableAttributeSeparator: string;
    function GetVariableEnd: string;
    function GetVariableIncompleteEnd: string;
    function GetVariableParser: string;
    function GetVariableSegment: string;
    function GetVariableSignature: string;
    function GetVariableStart: string;
  public
    constructor Create;
    property FilterSeparator: string read GetFilterSeparator;
    property ArgumentSeparator: string read GetArgumentSeparator;
    property FilterArgumentSeparator: string read GetFilterArgumentSeparator;
    property VariableAttributeSeparator: string read GetVariableAttributeSeparator;
    property TagStart: string read GetTagStart;
    property TagEnd: string read GetTagEnd;
    property VariableSignature: string read GetVariableSignature;
    property VariableSegment: string read GetVariableSegment;
    property VariableStart: string read GetVariableStart;
    property VariableEnd: string read GetVariableEnd;
    property VariableIncompleteEnd: string read GetVariableIncompleteEnd;
    property QuotedString: string read GetQuotedString;
    property QuotedFragment: string read GetQuotedFragment;
    property QuotedAssignFragment: string read GetQuotedAssignFragment;
    property StrictQuotedFragment: string read GetStrictQuotedFragment;
    property FirstFilterArgument: string read GetFirstFilterArgument;
    property OtherFilterArgument: string read GetOtherFilterArgument;
    property SpacelessFilter: string read GetSpacelessFilter;
    property Expression: string read GetExpression;
    property TagAttributes: string read GetTagAttributes;
    property AnyStartingTag: string read GetAnyStartingTag;
    property PartialTemplateParser: string read GetPartialTemplateParser;
    property TemplateParser: string read GetTemplateParser;
    property VariableParser: string read GetVariableParser;
    property LiteralShorthand: string read GetLiteralShorthand;
    property CommentShorthand: string read GetCommentShorthand;
    property SingleQuotedRegex: TRegEx read FSingleQuotedRegex;
    property DoubleQuotedRegex: TRegEx read FDoubleQuotedRegex;
    property IntegerRegex: TRegEx read FIntegerRegex;
    property RangeRegex: TRegEx read FRangeRegex;
    property NumericRegex: TRegEx read FNumericRegex;
    property SquareBracketedRegex: TRegEx read FSquareBracketedRegex;
    property VariableParserRegex: TRegEx read FVariableParserRegex;
  end;

function LiquidRegexes: TLiquid;

implementation

uses
  Liquid.Template,
  Liquid.Utils;

var
  _Liquid: TLiquid;

function LiquidRegexes: TLiquid;
begin
  if _Liquid = nil then
    _Liquid := TLiquid.Create;
  Result := _Liquid;
end;

{ TLiquid }

constructor TLiquid.Create;
begin
  FFilterSeparator := R.Q('\|');
  FArgumentSeparator := R.Q(',');
  FFilterArgumentSeparator := R.Q(':');
  FVariableAttributeSeparator := R.Q('.');
  FTagStart := R.Q('\{\%');
  FTagEnd := R.Q('\%\}');
  FVariableSignature := R.Q('\(?[\w\-\.\[\]]\)?');
  FVariableSegment := R.Q('[\w\-]');
  FVariableStart := R.Q('\{\{');
  FVariableEnd := R.Q('\}\}');
  FVariableIncompleteEnd := R.Q('\}\}?');
  FQuotedString := R.Q('"[^"]*"|''[^'']*''');
  FQuotedFragment := R.Q('%0:s|(?:[^\s,\|''"]|%0:s)+');
  FQuotedAssignFragment := R.Q('%0:s|(?:[^\s\|''"]|%0:s)+');
  FStrictQuotedFragment := R.Q('"[^"]+"|''[^'']+''|[^\s\|\:\,]+');
  FFirstFilterArgument := R.Q('%0:s(?:%1:s)');
  FOtherFilterArgument := R.Q('%0:s(?:%1:s)');
  FSpacelessFilter := R.Q('^(?:''[^'']+''|"[^"]+"|[^''"])*%0:s(?:%1:s)(?:%2:s(?:%3:s)*)?');
  FExpression := R.Q('(?:%0:s(?:%1:s)*)');
  FTagAttributes := R.Q('(\w+)\s*\:\s*(%0:s)');
  FAnyStartingTag := R.Q('\{\{|\{\%');
  FPartialTemplateParser := R.Q('%0:s.*?%1:s|%2:s.*?%3:s');
  FTemplateParser := R.Q('(%0:s|%1:s)');
  FVariableParser := R.Q('\[[^\]]+\]|%0:s+\??');
  FLiteralShorthand := R.Q('^(?:\{\{\{\s?)(.*?)(?:\s*\}\}\})$');
  FCommentShorthand := R.Q('^(?:\{\s?\#\s?)(.*?)(?:\s*\#\s?\})$');

  //
  // regexes
  FSingleQuotedRegex := R.C(R.Q('^''(.*)''$'));
  FDoubleQuotedRegex := R.C(R.Q('^"(.*)"$'));
  FIntegerRegex := R.C(R.Q('^([+-]?\d+)$'));
  FRangeRegex := R.C(R.Q('^\((\S+)\.\.(\S+)\)$'));
  FNumericRegex := R.C(R.Q('^([+-]?\d[\d\.|\,]+)$'));
  FSquareBracketedRegex := R.C(R.Q('^\[(.*)\]$'));
  FVariableParserRegex := R.C(VariableParser);
end;

function TLiquid.GetAnyStartingTag: string;
begin
  Result := FAnyStartingTag;
end;

function TLiquid.GetArgumentSeparator: string;
begin
  Result := FArgumentSeparator;
end;

function TLiquid.GetCommentShorthand: string;
begin
  Result := FCommentShorthand;
end;

function TLiquid.GetExpression: string;
begin
  Result := Format(FExpression, [QuotedFragment, SpacelessFilter]);
end;

function TLiquid.GetFilterArgumentSeparator: string;
begin
  Result := FFilterArgumentSeparator;
end;

function TLiquid.GetFilterSeparator: string;
begin
  Result := FFilterSeparator;
end;

function TLiquid.GetFirstFilterArgument: string;
begin
  Result := Format(FFirstFilterArgument,
    [FilterArgumentSeparator, StrictQuotedFragment]);
end;

function TLiquid.GetLiteralShorthand: string;
begin
  Result := FLiteralShorthand;
end;

function TLiquid.GetOtherFilterArgument: string;
begin
  Result := Format(FOtherFilterArgument,
    [ArgumentSeparator, StrictQuotedFragment]);
end;

function TLiquid.GetPartialTemplateParser: string;
begin
  Result := Format(FPartialTemplateParser,
    [TagStart, TagEnd, VariableStart, VariableIncompleteEnd]);
end;

function TLiquid.GetQuotedAssignFragment: string;
begin
  Result := Format(FQuotedAssignFragment, [QuotedString]);
end;

function TLiquid.GetQuotedFragment: string;
begin
  Result := Format(FQuotedFragment, [QuotedString]);
end;

function TLiquid.GetQuotedString: string;
begin
  Result := FQuotedString;
end;

function TLiquid.GetSpacelessFilter: string;
begin
  Result := Format(FSpacelessFilter,
    [FilterSeparator, StrictQuotedFragment, FirstFilterArgument,
     OtherFilterArgument]);
end;

function TLiquid.GetStrictQuotedFragment: string;
begin
  Result := FStrictQuotedFragment;
end;

function TLiquid.GetTagAttributes: string;
begin
  Result := Format(FTagAttributes, [QuotedFragment]);
end;

function TLiquid.GetTagEnd: string;
begin
  Result := FTagEnd;
end;

function TLiquid.GetTagStart: string;
begin
  Result := FTagStart;
end;

function TLiquid.GetTemplateParser: string;
begin
  Result := Format(FTemplateParser, [PartialTemplateParser, AnyStartingTag]);
end;

function TLiquid.GetVariableAttributeSeparator: string;
begin
  Result := FVariableAttributeSeparator;
end;

function TLiquid.GetVariableEnd: string;
begin
  Result := FVariableEnd;
end;

function TLiquid.GetVariableIncompleteEnd: string;
begin
  Result := FVariableIncompleteEnd;
end;

function TLiquid.GetVariableParser: string;
begin
  Result := Format(FVariableParser, [VariableSegment]);
end;

function TLiquid.GetVariableSegment: string;
begin
  Result := FVariableSegment;
end;

function TLiquid.GetVariableSignature: string;
begin
  Result := FVariableSignature;
end;

function TLiquid.GetVariableStart: string;
begin
  Result := FVariableStart;
end;

initialization

finalization
  _Liquid.Free;

end.
