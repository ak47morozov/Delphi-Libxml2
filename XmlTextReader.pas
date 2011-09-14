{
  LibXml2-XmlTextReader wrapper class for Delphi

  Copyright (c) 2010 Tobias Grimm

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
}

unit XmlTextReader;

interface

uses

  classes,
  sysutils,
  libxml2;

type
  EArgumentNullException = class(Exception);
  EArgumentOutOfRangeException = class(Exception);
  EXmlException = class(Exception);

  TXmlParserProperties = set of xmlParserProperties;

  TIntegerAttribAccessFunc = function(reader: xmlTextReaderPtr): Longint; cdecl;

  TXmlNodeType =
  (
    ntNone, // = 0,
    ntElement, // = 1,
    ntAttribute, // = 2,
    ntText, // = 3,
    ntCDATA, // = 4,
    ntEntityReference, // = 5,
    ntEntity, // = 6,
    ntProcessingInstruction, // = 7,
    ntComment, // = 8,
    ntDocument, // = 9,
    ntDocumentType, // = 10,
    ntDocumentFragment, // = 11,
    ntNotation, // = 12,
    ntWhitespace, // = 13,
    ntSignificantWhitespace, // = 14,
    ntEndElement, // = 15,
    ntEndEntity, // = 16,
    ntXmlDeclaration  // = 17
  );

  TXmlTextReader = class
  private FStream: TStream;
    FXmlTextReaderPtr: xmlTextReaderPtr;
    FXmlParserInputBufferPtr: xmlParserInputBufferPtr;
    FLastError: string;
    FEof: boolean;
    FInternalStream: TFileStream;
  private
    procedure InitLibxml2Objects;
    procedure FreeLibxml2Objects;
    function GetStream: TStream;
    procedure SetLastError(const ErrorMessage: string);
    function PXmlCharToStr(xmlChar: PXmlChar): string;
    function GetIntegerAttribute(IntegerAttribAccessFunc: TIntegerAttribAccessFunc): Integer;
    function GetBooleanAttribute(IntegerAttribAccessFunc: TIntegerAttribAccessFunc): boolean;
    function CheckError(FunctionResult: Integer): boolean;
  private
    function GetName: string;
    function GetLocalName: string;
    function GetPrefix: string;
    function GetNameSpaceUri: string;
    function GetAttributeCount: Integer;
    function GetDepth: Integer;
    function GetHasAttributes: boolean;
    function GetHasValue: boolean;
    function GetValue: string;
    function GetIsEmptyElement: boolean;
    function GetTmlParserProperties: TXmlParserProperties;
    function GetNodeType: TXmlNodeType;
    procedure SetXmlParserProperties(const Value: TXmlParserProperties);
  public
    constructor Create(Stream: TStream); overload;
    constructor Create(FileName: string); overload;
    destructor Destroy; override;
  public
    function Read: boolean;
    procedure Reset;
    function GetAttribute(const Name: string): string; overload;
    function GetAttribute(No: Integer): string; overload;
    function GetAttribute(const LocalName: string; const NamespaceUri: string): string; overload;
    function MoveToAttribute(const Name: string): boolean; overload;
    procedure MoveToAttribute(No: Integer); overload;
    function MoveToAttribute(const LocalName: string; const NamespaceUri: string): boolean; overload;
    function MoveToFirstAttribute: boolean;
    function MoveToNextAttribute: boolean;
    function MoveToElement: boolean;
    function LookupNamespace(const Prefix: string): string;
    function ReadInnerXml: string;
    function ReadOuterXml: string;
    function ReadString: string;
    procedure Skip;
  public
    property Name: string read GetName;
    property LocalName: string read GetLocalName;
    property Prefix: string read GetPrefix;
    property NamespaceUri: string read GetNameSpaceUri;
    property AttributeCount: Integer read GetAttributeCount;
    property Depth: Integer read GetDepth;
    property HasAttributes: boolean read GetHasAttributes;
    property HasValue: boolean read GetHasValue;
    property Value: string read GetValue;
    property IsEmptyElement: boolean read GetIsEmptyElement;
    property ParserProperties : TXmlParserProperties read GetTmlParserProperties write SetXmlParserProperties;
    property NodeType: TXmlNodeType read GetNodeType;
  end;

implementation

function ReadCallback(context: Pointer; buffer: PChar; len: Integer): Longint; cdecl;
begin
  Result := TXmlTextReader(context).GetStream.Read(buffer^, len);
end;

procedure xmlTextReaderErrorFunc(arg: Pointer; const msg: PChar; severity: xmlParserSeverities; locator: xmlTextReaderLocatorPtr); cdecl;
begin
  TXmlTextReader(arg).SetLastError(Utf8ToAnsi(PAnsiChar(msg)));
end;

constructor TXmlTextReader.Create(Stream: TStream);
begin
  if not assigned(Stream) then
    raise EArgumentNullException.Create('Stream');

  FStream := Stream;

  InitLibxml2Objects;
end;

destructor TXmlTextReader.Destroy;
begin
  FreeLibxml2Objects;
  FInternalStream.Free;
  inherited;
end;

procedure TXmlTextReader.FreeLibxml2Objects;
begin
  if assigned(FXmlTextReaderPtr) then
    libxml2.xmlFreeTextReader(FXmlTextReaderPtr);

  FXmlTextReaderPtr := nil;

  if assigned(FXmlParserInputBufferPtr) then
    libxml2.xmlFreeParserInputBuffer(FXmlParserInputBufferPtr);

  FXmlParserInputBufferPtr := nil;
end;

function TXmlTextReader.GetStream: TStream;
begin
  Result := FStream;
end;

procedure TXmlTextReader.InitLibxml2Objects;
begin
  FXmlParserInputBufferPtr := xmlAllocParserInputBuffer(XML_CHAR_ENCODING_NONE);
  if assigned(FXmlParserInputBufferPtr) then
  begin
    FXmlParserInputBufferPtr.context := self;
    FXmlParserInputBufferPtr.ReadCallback := ReadCallback;
  end
  else
    raise Exception.Create('libxml2: error creating xmlParserInputBuffer');

  FXmlTextReaderPtr := xmlNewTextReader(FXmlParserInputBufferPtr, '');
  if assigned(FXmlTextReaderPtr) then
    xmlTextReaderSetErrorHandler(FXmlTextReaderPtr, xmlTextReaderErrorFunc,
      self)
  else
    raise Exception.Create('libxml2: error creating xmlTextReader');
end;

function TXmlTextReader.Read: boolean;
begin
  if FEof then
    Result := False
  else
    Result := CheckError(XmlTextReaderRead(FXmlTextReaderPtr));
  FEof := not Result;
end;

procedure TXmlTextReader.Reset;
begin
  FLastError := '';
  FEof := False;
  FreeLibxml2Objects;
  InitLibxml2Objects;
end;

procedure TXmlTextReader.SetLastError(const ErrorMessage: string);
begin
  FLastError := ErrorMessage;
end;

function TXmlTextReader.GetName: string;
begin
  Result := PXmlCharToStr(xmlTextReaderName(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetLocalName: string;
begin
  Result := PXmlCharToStr(xmlTextReaderLocalName(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetPrefix: string;
begin
  Result := PXmlCharToStr(xmlTextReaderPrefix(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetNameSpaceUri: string;
begin
  Result := PXmlCharToStr(xmlTextReaderNameSpaceUri(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetAttributeCount: Integer;
begin
  Result := GetIntegerAttribute(xmlTextReaderAttributeCount);
end;

function TXmlTextReader.GetDepth: Integer;
begin
  Result := GetIntegerAttribute(xmlTextReaderDepth);
end;

function TXmlTextReader.GetIntegerAttribute
(IntegerAttribAccessFunc: TIntegerAttribAccessFunc): Integer;
begin
  Result := IntegerAttribAccessFunc(FXmlTextReaderPtr);
  CheckError(Result);
end;

function TXmlTextReader.GetHasAttributes: boolean;
begin
  Result := GetBooleanAttribute(xmlTextReaderHasAttributes);
end;

function TXmlTextReader.GetHasValue: boolean;
begin
  Result := GetBooleanAttribute(xmlTextReaderHasValue);
end;

function TXmlTextReader.GetValue: string;
begin
  Result := PXmlCharToStr(xmlTextReaderValue(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetIsEmptyElement: boolean;
begin
  Result := GetBooleanAttribute(xmlTextReaderisEmptyElement);
end;

function TXmlTextReader.GetBooleanAttribute
(IntegerAttribAccessFunc: TIntegerAttribAccessFunc): boolean;
begin
  Result := (GetIntegerAttribute(IntegerAttribAccessFunc) = 1);
end;

function TXmlTextReader.GetAttribute(const Name: string): string;
begin
  Result := PXmlCharToStr(XmlTextReaderGetAttribute(FXmlTextReaderPtr,
      PAnsiChar(AnsiToUtf8(Name))));
end;

function TXmlTextReader.GetAttribute(No: Integer): string;
begin
  Result := PXmlCharToStr(XmlTextReaderGetAttributeNo(FXmlTextReaderPtr, No));
end;

function TXmlTextReader.GetAttribute(const LocalName, NamespaceUri: string)
: string;
begin
  Result := PXmlCharToStr(XmlTextReaderGetAttributeNs(FXmlTextReaderPtr,
      PAnsiChar(AnsiToUtf8(LocalName)), PAnsiChar(AnsiToUtf8(NamespaceUri))));
end;

function TXmlTextReader.MoveToAttribute(const Name: string): boolean;
begin
  Result := CheckError(XmlTextReaderMoveToAttribute(FXmlTextReaderPtr,
      PAnsiChar(AnsiToUtf8(Name))));
end;

function TXmlTextReader.CheckError(FunctionResult: Integer): boolean;
begin
  if FunctionResult < 0 then
    if FLastError <> '' then
      raise EXmlException.Create(FLastError)
    else
      Result := False
    else
      Result := (FunctionResult = 1);
end;

procedure TXmlTextReader.MoveToAttribute(No: Integer);
begin
  if not CheckError(XmlTextReaderMoveToAttributeNo(FXmlTextReaderPtr, No)) then
    raise EArgumentOutOfRangeException.Create('');
end;

function TXmlTextReader.MoveToAttribute(const LocalName, NamespaceUri: string): boolean;
begin
  Result := CheckError(XmlTextReaderMoveToAttributeNs(FXmlTextReaderPtr,
      PAnsiChar(AnsiToUtf8(LocalName)), PAnsiChar(AnsiToUtf8(NamespaceUri))));
end;

function TXmlTextReader.MoveToFirstAttribute: boolean;
begin
  Result := CheckError(XmlTextReaderMoveToFirstAttribute(FXmlTextReaderPtr));
end;

function TXmlTextReader.MoveToNextAttribute: boolean;
begin
  Result := CheckError(XmlTextReaderMoveToNextAttribute(FXmlTextReaderPtr));
end;

function TXmlTextReader.MoveToElement: boolean;
begin
  Result := CheckError(XmlTextReaderMoveToElement(FXmlTextReaderPtr));
end;

function TXmlTextReader.PXmlCharToStr(xmlChar: PXmlChar): string;
begin
  if assigned(xmlChar) then
  begin
    Result := Utf8ToAnsi(xmlChar);
    xmlFree(xmlChar);
  end
  else
  begin
    Result := '';
  end;
end;

function TXmlTextReader.LookupNamespace(const Prefix: string): string;
begin
  Result := PXmlCharToStr(XmlTextReaderLookupNamespace(FXmlTextReaderPtr,
      PAnsiChar(AnsiToUtf8(Prefix))));
end;

function TXmlTextReader.ReadInnerXml: string;
begin
  Result := PXmlCharToStr(XmlTextReaderReadInnerXml(FXmlTextReaderPtr));
end;

function TXmlTextReader.ReadOuterXml: string;
var
  node: xmlNodePtr;
  buffer: xmlBufferPtr;
begin
  node := XmlTextReaderExpand(FXmlTextReaderPtr);
  Result := '';
  if assigned(node) then
  begin
    buffer := xmlBufferCreate;
    try
      if xmlNodeDump(buffer, node.doc, node, 0, 0) > 0 then
        Result := Utf8ToAnsi(buffer.content);
    finally
      xmlBufferFree(buffer);
    end;
  end;
  // Result := PXmlCharToStr(XmlTextReaderReadOuterXml(FXmlTextReaderPtr));
end;

function TXmlTextReader.ReadString: string;
begin
  Result := PXmlCharToStr(XmlTextReaderReadString(FXmlTextReaderPtr));
end;

function TXmlTextReader.GetTmlParserProperties: TXmlParserProperties;
begin
  if CheckError(XmlTextReaderGetParserProp(FXmlTextReaderPtr,
      ord(XML_PARSER_LOADDTD))) then
    Result := [XML_PARSER_LOADDTD]
  else
    Result := [];
end;

procedure TXmlTextReader.SetXmlParserProperties(const Value: TXmlParserProperties);
var
  prop: xmlParserProperties;
  propIsSet: Integer;
begin
  for prop := LOW(prop) to HIGH(prop) do
  begin
    if prop in Value then
      propIsSet := 1
    else
      propIsSet := 0;
    CheckError(XmlTextReaderSetParserProp(FXmlTextReaderPtr, ord(prop),
        propIsSet))
  end;
end;

constructor TXmlTextReader.Create(FileName: string);
begin
  FXmlTextReaderPtr := libxml2.xmlNewTextReaderFilename
  (PChar(AnsiString(FileName)));
  if assigned(FXmlTextReaderPtr) then
    xmlTextReaderSetErrorHandler(FXmlTextReaderPtr, xmlTextReaderErrorFunc,
      self)
  else
    raise EXmlException.Create('Error opening XML file');
end;

function TXmlTextReader.GetNodeType: TXmlNodeType;
begin
  case xmlTextReaderNodeType(FXmlTextReaderPtr) of
    1: Result := ntElement;
    2: Result := ntAttribute;
    3: Result := ntText;
    4: Result := ntCDATA;
    5: Result := ntEntityReference;
    6: Result := ntEntity;
    7: Result := ntProcessingInstruction;
    8: Result := ntComment;
    9: Result := ntDocument;
    10: Result := ntDocumentType;
    11: Result := ntDocumentFragment;
    12: Result := ntNotation;
    13: Result := ntWhitespace;
    14: Result := ntSignificantWhitespace;
    15: Result := ntEndElement;
    16: Result := ntEndEntity;
    17: Result := ntXmlDeclaration;
  else
    Result := ntNone;
  end;
end;

procedure TXmlTextReader.Skip;
begin
  CheckError(xmlTextReaderNext(FXmlTextReaderPtr));
end;

initialization

// required for thread safety since 2.4.7 see: http://xmlsoft.org/threads.html
xmlInitParser();

end.
