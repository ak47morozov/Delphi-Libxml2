// Original was here
// https://mail.gnome.org/archives/xml/2007-February/msg00015.html

program Schematest;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  windows,
  libxml2;


function GetStrFromError( error : xmlErrorPtr ) : string;
begin
  result := 'line:'+ IntToStr( error.line ) + ' - ' + error.message ;
end;

procedure ErrorFunc(ctx: pointer; const msg: PAnsiChar ); cdecl;
var
  ptr_args: array[0..100] of Pointer absolute msg;
  buffer: AnsiString;
  len: integer;
type
  PFile = ^Text;
begin
  SetLength(buffer, 1024); // Allocate enough space
  len := wvsprintfA(PAnsiChar(buffer), msg, @(ptr_args[1]));
  SetLength(buffer, len);  // Truncate to the actual string length
  if Assigned(ctx) then
    write(PFile(ctx)^, buffer)
  else
    write(buffer);
end;

procedure StructuredErrorFunc(userData: Pointer; error: xmlErrorPtr); cdecl;
type
  PFile = ^Text;
begin
  Writeln ( GetStrFromError( error ) );
  if Assigned(userData) then
    write(PFile(userData)^, GetStrFromError( error ) )
  else
    write( GetStrFromError( error ));
end;

var
  parserCtxt: xmlSchemaParserCtxtPtr;
  validCtxt: xmlSchemaValidCtxtPtr;
  doc: xmlDocPtr;
  schema: xmlSchemaPtr;
  ret: integer;
  logfile: Text;
  ss : AnsiString;
  ss2 : AnsiString;
begin
  if ParamCount < 2 then
    writeln('Usage: ' + ParamStr(0) + ' schemaFile xmlFile')
  else
  begin
    AssignFile (logfile, 'test.log');
    Rewrite(logfile);
    ss :=  ParamStr(1);
    ss2 := ParamStr(2);
    parserCtxt := xmlSchemaNewParserCtxt(PAnsiChar(ss));
    xmlSchemaSetParserErrors(parserCtxt,
        xmlSchemaValidityErrorFunc(@ErrorFunc),
        xmlSchemaValidityWarningFunc(@ErrorFunc),
        @logfile);
    schema := xmlSchemaParse(parserCtxt);
    xmlSchemaFreeParserCtxt(parserCtxt);

    if Assigned(schema) then
    begin
      doc := xmlReadFile(PAnsiChar(ss2), nil, 0);
      if (doc = nil) then
          writeln('Could not parse ' + ss2)
      else
      begin
        validCtxt := xmlSchemaNewValidCtxt(schema);
        xmlSchemaSetValidStructuredErrors(validCtxt,
            xmlStructuredErrorFunc(@StructuredErrorFunc),
            @logfile);
        ret := xmlSchemaValidateDoc(validCtxt, doc);
        write (ss2);
        if (ret = 0) then
          writeln (' validates')
        else if (ret > 0) then
          writeln (' fails to validate')
        else
          writeln(' validation generated an internal error');
        xmlSchemaFreeValidCtxt(validCtxt);
        xmlFreeDoc(doc);
      end;
    end;
    CloseFile(logfile);
    xmlSchemaCleanupTypes();
    xmlCleanupParser();
  end;
end.

