unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.FMXUI.Wait, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.IOUtils,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, System.Net.HttpClientComponent, System.Net.HttpClient,
  System.JSON, System.Net.URLClient, System.Generics.Collections, FMX.StdCtrls,
  FMX.ListBox, FMX.Colors;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    FDConnection1: TFDConnection;
    FDQuery1: TFDQuery;
    ToolBar1: TToolBar;
    ComboBox1: TComboBox;
    ToolBar2: TToolBar;
    Button2: TButton;
    Button3: TButton;
    Button1: TButton;
    ToolBar3: TToolBar;
    ComboBox2: TComboBox;
    Switch1: TSwitch;
    Memo2: TMemo;
    NetHTTPClient1: TNetHTTPClient;
    procedure FormCreate(Sender: TObject);
    procedure CreateDatabase;
    function ExecutePostRequest(const url: string; const PostData: TJSONObject = nil):string;
    procedure DeleteDataBase;
    procedure Button2Click(Sender: TObject);
    procedure addLog(const str: string);
    procedure fillBandList;
    procedure fillSongList(const _idband: string);
    procedure ComboBox1Change(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Switch1Switch(Sender: TObject);
    procedure ComboBox2Change(Sender: TObject);
    function IsInternetAvailable: Boolean;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  dbName, url: string;

implementation

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
begin
  dbName := 'songTexts.db';
  url := 'https://pepelac1.ddns.net';
  CreateDatabase;
  fillBandList;
end;

function TForm1.IsInternetAvailable: Boolean;
var
  HTTPClient: TNetHTTPClient;
  Response: IHTTPResponse;
begin
  HTTPClient := TNetHTTPClient.Create(nil);
  try
    try
      Response := HTTPClient.Get(url);
      //Result := (Response.StatusCode = 200);
      Result := (Response.StatusCode = 401);
    except
      on E: Exception do
        Result := False;
    end;
  finally
    HTTPClient.Free;
  end;
end;

procedure TForm1.Switch1Switch(Sender: TObject);
begin
  if Switch1.IsChecked then
  begin
    Memo1.Visible := True;
    Memo2.Visible := False;
  end
  else
  begin
    Memo1.Visible := False;
    Memo2.Visible := True;
  end;
end;

procedure TForm1.fillBandList;
var
  bandName, _idband: string;
  ID: integer;
begin
  FDQuery1.SQL.Text := 'SELECT * FROM bands';
  FDQuery1.Open;
  while not FDQuery1.Eof do
  begin
    bandName := FDQuery1.FieldByName('name').AsString;
    _idband := FDQuery1.FieldByName('_idband').AsString;
    ID := FDQuery1.FieldByName('ID').AsInteger;
    addLog(Format('ID: %d, _idband: %s, Name: %s', [ID, _idband, bandName]));
    ComboBox1.Items.AddObject(bandName, TObject(ID));
    FDQuery1.Next;
  end;
  FDQuery1.Close;
  Combobox1.ItemIndex := 0;
end;

procedure TForm1.fillSongList(const _idband: string);
var
  songName, _idsong: string;
  ID: integer;
begin
  FDQuery1.SQL.Text := 'SELECT * FROM songs WHERE _idband = :idband';
  FDQuery1.ParamByName('idband').AsString := _idband;
  FDQuery1.Open;
  while not FDQuery1.Eof do
  begin
    songName := FDQuery1.FieldByName('name').AsString;
    _idsong := FDQuery1.FieldByName('_idsong').AsString;
    ID := FDQuery1.FieldByName('ID').AsInteger;
    addLog(Format('ID: %d, _idsong: %s, Name: %s', [ID, _idsong, songName]));
    ComboBox2.Items.AddObject(songName, TObject(ID));
    FDQuery1.Next;
  end;
  FDQuery1.Close;
  Combobox2.ItemIndex := 0;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  DeleteDatabase;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
var
  SelectedID, I: integer;
  _idband, _idsong, songName, songText, Responce: string;
  PostData, JSONObject: TJSONObject;
  JSONArray: TJSONArray;
begin
  SelectedID := Integer(ComboBox1.Items.Objects[ComboBox1.ItemIndex]);
  FDQuery1.SQL.Text := 'SELECT _idband FROM bands WHERE ID = :ID';
  FDQuery1.ParamByName('ID').AsInteger := SelectedID;
  FDQuery1.Open;
  if not FDQuery1.Eof then
  begin
    _idband := FDQuery1.FieldByName('_idband').AsString;
    Memo1.Lines.Add('Found _idband: ' + _idband);
    if IsInternetAvailable then
    begin
      PostData := TJSONObject.Create;
      PostData.AddPair('_idband', _idband);
      try
        Responce := ExecutePostRequest(url + '/song-list', PostData);
      except
        on E: Exception do
          Responce := '[]';
      end;
      //addLog(Responce);
      PostData.Free;
    end
    else
    begin
      Memo1.Lines.Add('Нет интернета!');
      Responce := '[]';
    end;
    JSONArray := TJSONObject.ParseJSONValue(Responce) as TJSONArray;

    try
      ComboBox2.Items.Clear;
    except
      on E: Exception do
        // игнорируем. Очистка при повторном запуске вышибает ошибку, однако сама очистка ComboBox2 происходит.
    end;

    try
      if JSONArray <> nil then
      begin
        for I := 0 to JSONArray.Count - 1 do
        begin
          JSONObject := JSONArray.Items[I] as TJSONObject;
          songName := JSONObject.GetValue<string>('name');
          songText := JSONObject.GetValue<string>('text');
          _idsong := JSONObject.GetValue<string>('_id');
          Memo1.Lines.Add(_idsong);
          Memo1.Lines.Add(songName);
          Memo1.Lines.Add(songText);
          FDQuery1.SQL.Text := 'SELECT COUNT(*) FROM songs WHERE _idsong = :idsong';
          FDQuery1.ParamByName('idsong').AsString := _idsong;
          FDQuery1.Open;
          if FDQuery1.Fields[0].AsInteger = 0 then
          begin
            FDQuery1.SQL.Text := 'INSERT INTO songs (_idband, _idsong, name, text) VALUES (:idband, :idsong, :name, :text)';
            FDQuery1.ParamByName('idband').AsString := _idband;
            FDQuery1.ParamByName('idsong').AsString := _idsong;
            FDQuery1.ParamByName('name').AsString := songName;
            FDQuery1.ParamByName('text').AsString := songText;
            FDQuery1.ExecSQL;
          end;
          FDQuery1.Close;
        end;
      end;
    finally
      JSONArray.Free;
      fillSongList(_idband);
    end;
  end
  else
  begin
    Memo1.Lines.Add('No band found with this ID.');
  end;
  FDQuery1.Close;
end;

procedure TForm1.ComboBox2Change(Sender: TObject);
var
  SelectedID: integer;
  songText: string;
begin
  SelectedID := Integer(ComboBox2.Items.Objects[ComboBox2.ItemIndex]);
  FDQuery1.SQL.Text := 'SELECT text FROM songs WHERE ID = :ID';
  FDQuery1.ParamByName('ID').AsInteger := SelectedID;
  FDQuery1.Open;
  if not FDQuery1.Eof then
  begin
    songText := FDQuery1.FieldByName('text').AsString;
    Memo2.Lines.Clear;
    Memo2.Lines.Add(songText);
  end;
end;

procedure TForm1.CreateDatabase;
var
  DBFileName: string;
  Responce: string;
  bandName: string;
  _idband: string;
  JSONArray: TJSONArray;
  JSONObject: TJSONObject;
  I: integer;
begin
  DBFileName := TPath.Combine(TPath.GetDocumentsPath, dbName);
  FDConnection1.Params.Database := DBFileName;
  FDConnection1.Connected := True;
  FDQuery1.SQL.Text := 'CREATE TABLE IF NOT EXISTS bands (ID INTEGER PRIMARY KEY, _idband text, name text)';
  FDQuery1.ExecSQL;
  FDQuery1.SQL.Text := 'CREATE TABLE IF NOT EXISTS songs (ID INTEGER PRIMARY KEY, _idband text, _idsong text, name text, text text)';
  FDQuery1.ExecSQL;
  if IsInternetAvailable then
  begin
    try
      Responce := ExecutePostRequest(url + '/band-list');
    except
      on E: Exception do
        Responce := '[]';
    end;
    addLog(Responce);
  end
  else
  begin
    Memo1.Lines.Add('Нет интернета!');
    Responce := '[]';
  end;

  JSONArray := TJSONObject.ParseJSONValue(Responce) as TJSONArray;
  try
    if JSONArray <> nil then
    begin
      for I := 0 to JSONArray.Count - 1 do
      begin
        JSONObject := JSONArray.Items[I] as TJSONObject;
        bandName := JSONObject.GetValue<string>('name');
        _idband := JSONObject.GetValue<string>('_id');
        Memo1.Lines.Add(_idband);
        Memo1.Lines.Add(bandName);
        FDQuery1.SQL.Text := 'SELECT COUNT(*) FROM bands WHERE _idband = :idband';
        FDQuery1.ParamByName('idband').AsString := _idband;
        FDQuery1.Open;
        if FDQuery1.Fields[0].AsInteger = 0 then
        begin
          FDQuery1.SQL.Text := 'INSERT INTO bands (_idband, name) VALUES (:idband, :name)';
          FDQuery1.ParamByName('idband').AsString := _idband;
          FDQuery1.ParamByName('name').AsString := bandName;
          FDQuery1.ExecSQL;
        end;
        FDQuery1.Close;
      end;
    end;
  finally
    JSONArray.Free;
  end;
end;

function TForm1.ExecutePostRequest(const url: string; const PostData: TJSONObject = nil): string;
var
  HTTPClient: TNetHTTPClient;
  Response: IHTTPResponse;
  StringResponce: string;
  LocalJSONObject: TJSONObject;
  IsTempObject: Boolean;
begin
  IsTempObject := False;
  if PostData = nil then
  begin
    LocalJSONObject := TJSONObject.Create;
    IsTempObject := True;
  end
  else
    LocalJSONObject := PostData;
  Result := '';
  HTTPClient := TNetHTTPClient.Create(nil);
  try
    Response := HTTPClient.Post(url, TStringStream.Create(LocalJSONObject.ToString, TEncoding.UTF8), nil, [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('x-api-key', 'my_API_key')]);
    if Response.StatusCode = 200 then
    begin
      StringResponce := Response.ContentAsString(TEncoding.UTF8);
      //try
        //WriteLn(StringResponce);
      //except
        //on E: Exception do
        // Just ignore WriteLn if it not work
      //end;
      Result := StringResponce;
    end
    else
      Result := Response.StatusText + ' (' + Response.StatusCode.ToString + ')';
  finally
    HTTPClient.Free;
    if IsTempObject then
      LocalJSONObject.Free;
  end;
end;

procedure TForm1.DeleteDatabase;
var
  DBFileName: string;
begin
  FDConnection1.Connected := False;
  DBFileName := TPath.Combine(TPath.GetDocumentsPath, dbName);
  if TFile.Exists(DBFileName) then
  begin
    TFile.Delete(DBFileName);
    addLog('Файл базы данных успешно удалён.');
  end
  else
  begin
    addLog('Файл базы данных не найден.');
  end;
  CreateDatabase;
end;

procedure TForm1.addLog(const str: string);
begin
  //Memo1.Lines.Add('');
  Memo1.Lines.Add(str);
  Memo1.Lines.Add('');
end;

end.

