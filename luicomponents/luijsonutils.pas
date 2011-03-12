unit LuiJSONUtils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, db;

type

  { TJSONFile }

  TJSONFile = class
  private
    FData: TJSONData;
    FFileName: String;
  public
    destructor Destroy; override;
    procedure Load;
    property Data: TJSONData read FData ;
    property FileName: String read FFileName write FFileName;
  end;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Boolean): Boolean;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Integer): Integer;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Double): Double;

function GetJSONProp(JSONObj: TJSONObject; const PropName, Default: String): String;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String): TJSONData;

function GetJSONPropValue(JSONObj: TJSONObject; const PropName: String): Variant;

procedure SetJSONPropValue(JSONObj: TJSONObject; const PropName: String; Value: Variant);

function FileToJSONData(const FileName: String): TJSONData;

function StringToJSONData(const JSONStr: TJSONStringType): TJSONData;

function StreamToJSONData(Stream: TStream): TJSONData;

function DatasetToJSONData(Dataset: TDataset; const Options: String): TJSONData;

implementation

uses
  jsonparser, Variants;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Boolean): Boolean;
var
  Data: TJSONData;
begin
  Data := GetJSONProp(JSONObj, PropName);
  if (Data <> nil) and (Data.JSONType <> jtNull) then
    Result := Data.AsBoolean
  else
    Result := Default;
end;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Integer): Integer;
var
  Data: TJSONData;
begin
  Data := GetJSONProp(JSONObj, PropName);
  if (Data <> nil) and (Data.JSONType <> jtNull) then
    Result := Data.AsInteger
  else
    Result := Default;
end;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String; Default: Double): Double;
var
  Data: TJSONData;
begin
  Data := GetJSONProp(JSONObj, PropName);
  if (Data <> nil) and (Data.JSONType <> jtNull) then
    Result := Data.AsFloat
  else
    Result := Default;
end;

function GetJSONProp(JSONObj: TJSONObject; const PropName, Default: String): String;
var
  Data: TJSONData;
begin
  Data := GetJSONProp(JSONObj, PropName);
  if (Data <> nil) and (Data.JSONType <> jtNull) then
    Result := Data.AsString
  else
    Result := Default;
end;

function GetJSONProp(JSONObj: TJSONObject; const PropName: String): TJSONData;
var
  i: Integer;
begin
  i := JSONObj.IndexOfName(PropName);
  if i <> -1 then
    Result := JSONObj.Items[i]
  else
    Result := nil;
end;

function GetJSONPropValue(JSONObj: TJSONObject; const PropName: String): Variant;
var
  Data: TJSONData;
begin
  Data := GetJSONProp(JSONObj, PropName);
  if Data = nil then
    Result := Null
  else
    Result := Data.Value;
end;

procedure SetJSONPropValue(JSONObj: TJSONObject; const PropName: String; Value: Variant);
var
  VariantType: tvartype;
begin
  VariantType := VarType(Value);
  case VariantType of
    varnull: JSONObj.Elements[PropName] := TJSONNull.Create;
    varstring: JSONObj.Elements[PropName] := TJSONString.Create(Value);
    vardouble, vardate: JSONObj.Elements[PropName] := TJSONFloatNumber.Create(Value);
    varinteger, varlongword: JSONObj.Elements[PropName] := TJSONIntegerNumber.Create(Value);
    varint64, varqword: JSONObj.Elements[PropName] := TJSONInt64Number.Create(Value);
    varboolean: JSONObj.Elements[PropName] := TJSONBoolean.Create(Value);
  else
    raise Exception.CreateFmt('SetJSONPropValue - Type %d not handled', [VariantType]);
  end
end;

function FileToJSONData(const FileName: String): TJSONData;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    Result := StreamToJSONData(Stream);
  finally
    Stream.Destroy;
  end;
end;

function StringToJSONData(const JSONStr: TJSONStringType): TJSONData;
var
  Parser: TJSONParser;
begin
  Parser := TJSONParser.Create(JSONStr);
  try
    Result := Parser.Parse;
  finally
    Parser.Destroy;
  end;
end;

function StreamToJSONData(Stream: TStream): TJSONData;
var
  Parser: TJSONParser;
begin
  Parser := TJSONParser.Create(Stream);
  try
    Result := Parser.Parse;
  finally
    Parser.Destroy;
  end;
end;

function DatasetRecToJSONObject(Dataset: TDataset): TJSONObject;
var
  i: Integer;
  Field: TField;
begin
  Result := TJSONObject.Create;
  for i := 0 to Dataset.Fields.Count - 1 do
  begin
    Field := Dataset.Fields[i];
    //todo: add option to preserve case
    //todo: add option to map fields
    SetJSONPropValue(Result, LowerCase(Field.FieldName), Field.AsVariant);
  end;
end;

function DatasetToJSONData(Dataset: TDataset; const Options: String): TJSONData;
var
  OptionsData: TJSONData;
begin
  OptionsData := StringToJSONData(Options);
  try
    case OptionsData.JSONType of
      jtObject:
        if GetJSONProp(TJSONObject(OptionsData), 'copyrecord', False) then
          Result := DatasetRecToJSONObject(Dataset);
      jtArray:
        ;
    end;
  finally
    OptionsData.Free;
  end;
end;

{ TJSONFile }

destructor TJSONFile.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

procedure TJSONFile.Load;
var
  Parser: TJSONParser;
  Stream: TFileStream;
begin
  //todo: handle UTF-8
  if not FileExists(FFileName) then
    raise Exception.CreateFmt('TJSONFile - File "%s" does not exist', [FFileName]);
  FreeAndNil(FData);
  Stream := nil;
  Parser := nil;
  try
    try
      Stream := TFileStream.Create(FFileName, fmOpenRead);
      Parser := TJSONParser.Create(Stream);
      FData := Parser.Parse;
    finally
      Parser.Free;
      Stream.Free;
    end;
  except
    on E: EFOpenError do
      raise Exception.CreateFmt('TJSONFile - Error loading "%s" : %s', [FFileName, E.Message]);
    on E: EJSONScanner do
    begin
       FData.Free;
       raise Exception.CreateFmt('TJSONFile - Error parsing "%s" : %s', [FFileName, E.Message]);
    end;
  end;
end;

end.

