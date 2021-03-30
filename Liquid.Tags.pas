unit Liquid.Tags;

interface

uses
  System.SysUtils,
  System.Classes, System.Generics.Collections,
  System.RegularExpressions,
  System.Rtti,

  Liquid.Default,
  Liquid.Interfaces,
  Liquid.Context,
  Liquid.Tag,
  Liquid.Block,
  Liquid.Variable,
  Liquid.Condition,
  Liquid.Exceptions,
  Liquid.Utils,
  Liquid.Hash;

type
  TAssign = class(TTag)
  strict private
    FTo: string;
    FFrom: TVariable;
    FSyntax: TRegEx;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize(const ATagName: string; const AMarkup: string;
      ATokens: TList<string>); override;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

  TIf = class(TBlock)
  strict private
    FExpressionsAndOperators: string;
    FSyntax: TRegEx;
    FExpressionsAndOperatorsRegex: TRegEx;
    FBlocks: TList<TCondition>;
  private
    procedure PushBlock(const ATagName: string; const AMarkup: string);
  protected
    property Blocks: TList<TCondition> read FBlocks;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize(const ATagName: string; const AMarkup: string;
      ATokens: TList<string>); override;
    procedure UnknownTag(const Tag: string; const Markup: string;
      Tokens: TList<string>); override;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

  TFor = class(TBlock)
  strict private
    FSyntax: TRegEx;
    FVariableName: string;
    FCollectionName: string;
    FName: string;
    FReversed: boolean;
    FAttributes: TDictionary<string, string>;
  private
    function SliceCollectionUsingEach(AContext: ILiquidContext;
      ACollection: TArray<TValue>; AFrom: integer; ATo: TValue): TArray<TValue>;
    procedure BuildContext(AContext: ILiquidContext; const AParent: string;
      const AKey: string; AValue: TValue);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize(const ATagName: string; const AMarkup: string;
      ATokens: TList<string>); override;
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

  TBreak = class(TTag)
  public
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

  TContinue = class(TTag)
  public
    procedure Render(Context: ILiquidContext; Writer: TTextWriter); override;
  end;

implementation

uses
  Liquid.Template;

const
  IfTagSyntaxExceptionMessage = 'Syntax Error in ''if'' tag - Valid syntax: if [expression]';
  IfTagTooMuchConditionsExceptionMessage = 'Syntax Error in ''if'' tag - max 500 conditions are allowed';
  ForTagMaximumIterationsExceededExceptionMessage = 'Render Error - Maximum number of iterations %d exceeded';
  ForTagSyntaxException = 'Syntax Error in ''for'' tag - Valid syntax: for [item] in [collection]';
{ TAssign }

constructor TAssign.Create;
begin
  FSyntax := R.B(R.Q('(%0:s+)\s*=\s*(.*)\s*'),
    [LiquidRegexes.VariableSignature]);
end;

destructor TAssign.Destroy;
begin
  FFrom.Free;
  inherited;
end;

procedure TAssign.Initialize(const ATagName, AMarkup: string;
  ATokens: TList<string>);
begin
  var SyntaxMatch := FSyntax.Match(AMarkup);
  if SyntaxMatch.Success then
  begin
    FTo := SyntaxMatch.Groups[1].Value;
    FFrom := TVariable.Create(SyntaxMatch.Groups[2].Value);
  end
  else
  begin
    raise ELiquidSyntaxException.Create(
      'Syntax Error in ''assign'' tag - Valid syntax: assign [var] = [source]');
  end;
  inherited Initialize(ATagName, AMarkup, ATokens);
end;

procedure TAssign.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  Context.Scopes.Last.AddOrSetValue(FTo, FFrom.Render(Context));
end;

{ TIf }

constructor TIf.Create;
begin
  inherited;
  FExpressionsAndOperators := Format(R.Q(
    '(?:\b(?:\s?and\s?|\s?or\s?)\b|(?:\s*(?!\b(?:\s?and\s?|\s?or\s?)\b)(?:%0:s|\S+)\s*)+)'),
    [LiquidRegexes.QuotedFragment]);
  FSyntax := R.B(R.Q('(%0:s)\s*([=!<>a-zA-Z_]+)?\s*(%0:s)?'),
    [LiquidRegexes.QuotedFragment]);
  FExpressionsAndOperatorsRegex := R.C(FExpressionsAndOperators);
  FBlocks := TObjectList<TCondition>.Create;
end;

destructor TIf.Destroy;
begin
  FBlocks.Free;
  inherited;
end;

procedure TIf.Initialize(const ATagName, AMarkup: string;
  ATokens: TList<string>);
begin
  PushBlock('if', AMarkup);
  inherited Initialize(ATagName, AMarkup, ATokens);
end;

procedure TIf.PushBlock(const ATagName, AMarkup: string);
begin
  var Block: TCondition;
  if ATagName.Equals('else') then
    Block := TElseCondition.Create
  else
  begin
    var Expressions := TList<string>.Create;
    try
      Expressions.AddRange(R.Scan(AMarkup, FExpressionsAndOperatorsRegex));
      var Syntax := TListHelper.TryGetAtIndexReverse(Expressions, 0);
      if string.IsNullOrEmpty(Syntax) then
        raise ELiquidSyntaxException.Create(IfTagSyntaxExceptionMessage);
      var SyntaxMatch := FSyntax.Match(Syntax);
      if not SyntaxMatch.Success then
        raise ELiquidSyntaxException.Create(IfTagSyntaxExceptionMessage);
      var Condition := TCondition.Create(SyntaxMatch);
      try
        var ConditionCount := 1;
        var I := 1;
        // continue to process remaining items in the list backwards, in pairs
        while I < Expressions.Count do
        begin
          var Op := TListHelper.TryGetAtIndexReverse(Expressions, I).Trim;
          var ExpressionMatch := FSyntax.Match(
            TListHelper.TryGetAtIndexReverse(Expressions, I + 1));
          if not ExpressionMatch.Success then
            raise ELiquidSyntaxException.Create(IfTagSyntaxExceptionMessage);
          Inc(ConditionCount);
          if ConditionCount > 500 then
            raise ELiquidSyntaxException.Create(IfTagTooMuchConditionsExceptionMessage);
          var NewCondition := TCondition.Create(ExpressionMatch);
          if Op = 'and' then
            NewCondition._And(Condition)
          else if Op = 'or' then
            NewCondition._Or(Condition);
          Condition := NewCondition;
          Inc(I, 2);
        end;
        Block := Condition;
      except
        Condition.Free;
        raise;
      end;
    finally
      Expressions.Free;
    end;
  end;
  Blocks.Add(Block);
  SetNodeList(Block.Attach(TNodeList.Create));
end;

procedure TIf.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  Context.Stack(
    procedure
    begin
      for var Block in Blocks do
        if Block.Evaluate(Context, Context.FormatSettings) then
        begin
          RenderAll(Block.Attachment, Context, Writer);
          Break;
        end;
    end
  );
end;

procedure TIf.UnknownTag(const Tag, Markup: string; Tokens: TList<string>);
begin
  if Tag.Equals('elsif') or Tag.Equals('elseif') or Tag.Equals('else') then
    PushBlock(Tag, Markup)
  else
    inherited UnknownTag(Tag, Markup, Tokens);
end;

{ TFor }

procedure TFor.BuildContext(AContext: ILiquidContext; const AParent,
  AKey: string; AValue: TValue);
begin
  if not AValue.IsType<IHash> then
  begin
    AContext[AParent + '.' + AKey] := AValue;
    Exit;
  end;
  var HashValue := AValue.AsType<IHash>;
  HashValue['itemName'] := AKey;
  AContext[AParent] := AValue;
  for var HashItem in HashValue.ToArray do
  begin
    if not HashItem.Value.IsType<IHash> then
      Continue;
    BuildContext(AContext, AParent + '.' + AKey, HashItem.Key, HashItem.Value);
  end;
end;

constructor TFor.Create;
begin
  inherited;
  FSyntax := R.B(R.Q('(\w+)\s+in\s+(%s+)\s*(reversed)?'),
    [LiquidRegexes.QuotedFragment]);
  FAttributes := TDictionary<string, string>.Create;
end;

destructor TFor.Destroy;
begin
  FAttributes.Free;
  inherited;
end;

procedure TFor.Initialize(const ATagName, AMarkup: string;
  ATokens: TList<string>);
begin
  var Match := FSyntax.Match(AMarkup);
  if Match.Success then
  begin
    FVariableName := Match.Groups[1].Value;
    FCollectionName := Match.Groups[2].Value;
    FName := Format('%s-%s', [FVariableName, FCollectionName]);
    FReversed := (Match.Groups.Count >= 4) and (not string.IsNullOrEmpty(Match.Groups[3].Value));
    R.Scan(AMarkup, LiquidRegexes.TagAttributes,
      procedure(Key, Value: string)
      begin
        FAttributes.AddOrSetValue(Key, Value);
      end
    );
  end
  else
  begin
    raise ELiquidSyntaxException.Create(ForTagSyntaxException);
  end;
  inherited Initialize(ATagName, AMarkup, ATokens);
end;

procedure TFor.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  if not Context.Registers.ContainsKey('for') then
    Context.Registers['for'] := TValue.From<IHash>(THash.Create(0));
  var Collection := Context[FCollectionName, False];
  if not Collection.IsType<TArray<TValue>> then
    Exit;
  var From: integer;
  if FAttributes.ContainsKey('offset') then
  begin
    var FromValue: TValue;
    if FAttributes['offset'] = 'continue' then
      FromValue := Context.Registers['for'].AsType<IHash>[FName]
    else
      FromValue := Context[FAttributes['offset']];
    FromValue := TConverter.ChangeType(FromValue, TypeInfo(integer), tkInteger);
    From := FromValue.AsInteger;
  end
  else
    From := 0;

  var Limit := TValue.Empty;
  if FAttributes.ContainsKey('limit') then
  begin
    var LimitValue := Context[FAttributes['limit']];
    if not LimitValue.IsEmpty then
    begin
      LimitValue := TConverter.ChangeType(LimitValue, TypeInfo(integer), tkInteger);
      Limit := LimitValue.AsInteger;
    end;
  end;
  var _To := TValue.Empty;
  if not Limit.IsEmpty then
    _To := Limit.AsInteger + From;

  var Segment := TList<TValue>.Create;
  try
    Segment.AddRange(SliceCollectionUsingEach(Context,
      Collection.AsType<TArray<TValue>>, From, _To));
    if Segment.Count = 0 then
      Exit;
    if FReversed then
      Segment.Reverse;
    var Length := Segment.Count;

    // Store our progress through the collection for the continue flag
    Context.Registers['for'].AsType<IHash>[FName] := From + Length;

    Context.Stack(
      procedure
      begin
        for var Index := 0 to Segment.Count - 1 do
        begin
          var Item := Segment[Index];
          if Item.IsType<IHash> then
          begin
            Context[FVariableName] := Item;
            for var HashItem in Item.AsType<IHash>.ToArray do
              BuildContext(Context, FVariableName, HashItem.Key, HashItem.Value);
          end
          else
          begin
            Context[FVariableName] := Item;
          end;

          var ForLoop: IHash := THash.Create;
          ForLoop['name'] := FName;
          ForLoop['length'] := Length;
          ForLoop['index'] := Index + 1;
          ForLoop['index0'] := Index;
          ForLoop['rindex'] := Length - Index;
          ForLoop['rindex0'] := Length - Index - 1;
          ForLoop['first'] := Index = 0;
          ForLoop['last'] := Index = (Length - 1);

          Context['forloop'] := TValue.From<IHash>(ForLoop);

          try
            RenderAll(NodeList, Context, Writer);
          except
            on E: EBreakInterrupt do
            begin
              Break;
            end;
            on E: EContinueInterrupt do
            begin
              // ContinueInterrupt is used only to skip the current value
              // but not to stop the iteration
            end;
          end;
        end;
      end
    );
  finally
    Segment.Free;
  end;
end;

function TFor.SliceCollectionUsingEach(AContext: ILiquidContext;
  ACollection: TArray<TValue>; AFrom: integer; ATo: TValue): TArray<TValue>;
begin
  var Segments := TList<TValue>.Create;
  try
    var Index := 0;
    for var Item in ACollection do
    begin
      if (not ATo.IsEmpty) and (ATo.AsInteger <= Index) then
        Break;
      if AFrom <= Index then
        Segments.Add(Item);
      Inc(Index);
      if (AContext.MaxIterations > 0) and (Index > AContext.MaxIterations) then
        raise EMaximumIterationsExceededException.CreateFmt(
          ForTagMaximumIterationsExceededExceptionMessage,
          [AContext.MaxIterations]);
    end;
    Result := Segments.ToArray;
  finally
    Segments.Free;
  end;
end;

{ TBreak }

procedure TBreak.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  raise EBreakInterrupt.Create;
end;

{ TContinue }

procedure TContinue.Render(Context: ILiquidContext; Writer: TTextWriter);
begin
  raise EContinueInterrupt.Create;
end;

initialization
  TLiquidTemplate.RegisterTag(TAssign, 'assign');
  TLiquidTemplate.RegisterTag(TIf, 'if');
  TLiquidTemplate.RegisterTag(TFor, 'for');
  TLiquidTemplate.RegisterTag(TBreak, 'break');
  TLiquidTemplate.RegisterTag(TContinue, 'continue');

end.
