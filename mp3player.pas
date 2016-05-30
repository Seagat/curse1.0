unit mp3player;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, BASS, sSkinManager, Buttons, sSpeedButton, sSkinProvider,
  ExtCtrls, sPanel, StdCtrls, sScrollBar, sAlphaListBox, sEdit, sSpinEdit,
  sLabel, acMagn, sGroupBox, sButton, ShellApi, sCheckBox, ComCtrls,
  sTrackBar;

type
  TFFTData = array [0..512] of Single;
  TfMain = class(TForm)
    dlgOpenFile: TOpenDialog;
    pnlCurrentSong: TsPanel;
    pnlButtonsAndCurrentSong: TsPanel;
    pnlProcessBar: TsPanel;
    sbProcessBar: TsScrollBar;
    sbtnPlay: TsSpeedButton;
    sbtnStop: TsSpeedButton;
    sbtnPause: TsSpeedButton;
    pnlVolume: TsPanel;
    sbVolume: TsScrollBar;
    pnlPlaylist: TsPanel;
    lbPublicPlaylist: TsListBox;
    sbtnAddSongOnPlaylist: TsSpeedButton;
    sbtnDeleteSongFromPlaylist: TsSpeedButton;
    lbPrivatePlaylist: TsListBox;
    sbtnNextSong: TsSpeedButton;
    sbtnPreviousSong: TsSpeedButton;
    pnlCurrentTime: TsPanel;
    pnlSongDuration: TsPanel;
    pnlWritePlaylist: TsPanel;
    gbCurrentSong: TsGroupBox;
    lbCurrentSong: TsLabel;
    pbEqualizer: TPaintBox;
    sbtnRepeatSong: TsSpeedButton;
    sbtnShufflePlaylist: TsSpeedButton;
    tmrRender: TTimer;
    gbEqualizer: TsGroupBox;
    skinManager: TsSkinManager;
    skinProvider: TsSkinProvider;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure sbtnOpenClick(Sender: TObject);
    procedure sbtnPlayClick(Sender: TObject);
    procedure sbtnPauseClick(Sender: TObject);
    procedure sbtnStopClick(Sender: TObject);
    procedure tmrRenderTimer(Sender: TObject);
    procedure sbProcessBarScroll(Sender: TObject; ScrollCode: TScrollCode;
      var ScrollPos: Integer);
    procedure sbtnAddSongOnPlaylistClick(Sender: TObject);
    procedure sbtnDeleteSongFromPlaylistClick(Sender: TObject);
    procedure lbPublicPlaylistDblClick(Sender: TObject);
    procedure sbVolumeScroll(Sender: TObject; ScrollCode: TScrollCode;
      var ScrollPos: Integer);
    procedure sbtnPreviousSongClick(Sender: TObject);
    procedure sbtnNextSongClick(Sender: TObject);
    procedure Draw (HWND: THandle; FFTData : TFFTData; X, Y: integer);
    procedure pbEqualizerPaint(Sender: TObject);
    procedure sbtnRepeatSongMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure sbtnRepeatSongClick(Sender: TObject);
    procedure sbtnShufflePlaylistClick(Sender: TObject);
    procedure WmDropFiles( var Msg: TWMDropFiles); message WM_DropFiles;
    procedure ShufflePlaylist;
    procedure sbtnShufflePlaylistMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Clearing;
    procedure AddFiles(filename: string);
    procedure PlayItem;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fMain: TfMain;
  Stream: HStream;
  Track: boolean;
  FFTPeacks, FFTFallOff: array [0..128] of integer;
  currentSong: integer;

implementation

{$R *.dfm}

procedure TfMain.FormCreate(Sender: TObject);
begin
   //�������������. ��� ������������� ������ ������� ���������.
   if Bass_Init(-1, 44100, 0, handle, nil) = false then
      ShowMessage('�� ������� ���������������� �����.');
   //����������� ������� Drag-and-Drop.
   DragAcceptFiles(handle, true);
end;

procedure TfMain.FormDestroy(Sender: TObject);
begin
   //������������ ������ ����� ������.
   BASS_FREE ();
end;

procedure TfMain.sbtnOpenClick(Sender: TObject);
begin
   //���� ���� �� ������, �� ������� �� ���������.
   if dlgOpenFile.Execute = false then exit;

   //����� �� ���� ��������� ������, ����������� �����, ���� �� ��� ����������.
	if Stream <> 0 then
		BASS_StreamFree(Stream);

   //�������� �����.
	stream:= Bass_streamCreateFile(false, PChar(dlgOpenFile.FileName),0,0,0);

	//���� ���� �� ����������, �� ������� ������.
	if Stream = 0 then
		ShowMessage('������ ���� �� ��������!')
	else
	begin
      //����� ��� �����.
		pnlCurrentSong.Caption:=ExtractFileName(dlgOpenFile.FileName);
      //��������� ����������� �������.
		sbProcessBar.Min:=0;
      //��������� ������������ �������.
		sbProcessBar.Max:=Bass_ChannelGetLength(stream,0)-1;
      //��������� ScrollBar'a.
		sbProcessBar.Position:=0;
	end;
end;

procedure TfMain.sbtnPlayClick(Sender: TObject);
begin

   //���� ����� � ��������� �����, �� ���������� ���������������.
   if Bass_ChannelisActive(stream)= Bass_Active_Paused then
      BASS_channelPlay(stream,false)
   else
      // ����� �������������� ���� ������.
      PlayItem;
   sbtnPlay.Enabled:=False;
end;

procedure TfMain.sbtnPauseClick(Sender: TObject);
begin
   //����� � ���������������.
   BASS_ChannelPause(stream);
end;

procedure TfMain.sbtnStopClick(Sender: TObject);
begin
   //��������� ���������������.
   BASS_ChannelStop(stream);

   //����������� ������� ������� � ������ ����������.
   BASS_ChannelSetPosition(stream,0,0);
end;

procedure TfMain.tmrRenderTimer(Sender: TObject);
var
   timeCurrentPosition, timeSongDuration: Double;
   FFTFata: TFFTData;
begin
   if lbPublicPlaylist.Items.Count>1 then
   begin
      sbtnNextSong.Enabled:=true;
      sbtnPreviousSong.Enabled:=true;
   end
   else
   begin
      sbtnNextSong.Enabled:=false;
      sbtnPreviousSong.Enabled:=false;
   end;

   if lbPublicPlaylist.Items.Count>2 then
      sbtnShufflePlaylist.Enabled:=true
   else
      sbtnShufflePlaylist.Enabled:=false;

   if lbPublicPlaylist.Items.Count>0 then
   begin
      sbtnRepeatSong.Enabled:=true;
      sbtnDeleteSongFromPlaylist.Enabled:=true;
      if Bass_ChannelisActive(stream)<> Bass_Active_Playing then
         sbtnPlay.Enabled:=true;
      sbtnPause.Enabled:=true;
      sbtnStop.Enabled:=true;
   end
   else
   begin
      sbtnRepeatSong.Enabled:=false;
      sbtnDeleteSongFromPlaylist.Enabled:=false;
      sbtnPlay.Enabled:=false;
      sbtnStop.Enabled:=false;
      sbtnPause.Enabled:=false;
   end;

   //���� �������� ��������, �� ������� ������� ������������� �������-����.
   if Track=false then
		sbProcessBar.Position:= Bass_ChannelGetPosition(stream,0);

   //��� ��������� ����� ������ ��������������� ����������.
   if BASS_ChannelGetPosition(stream, 0)=BASS_ChannelGetLength(stream, 0) then
   begin
      if sbtnRepeatSong.Down then
         sbtnPlayClick(Sender);
      if currentSong<lbPublicPlaylist.Items.Count-1 then
      begin
         if not sbtnRepeatSong.Down then
            if not sbtnShufflePlaylist.Down then
               inc(currentSong)
            else
               ShufflePlaylist;
         lbPublicPlaylist.ItemIndex:=currentSong;
         sbtnPlayClick(Sender);
      end
      else
         if sbtnShufflePlaylist.Down then
            ShufflePlaylist;
   end;

   //����� ������������ �����.
   //���������� ������ � ������ ��������������� �����.
   timeCurrentPosition:=BASS_ChannelBytes2Seconds(stream, BASS_ChannelGetPosition(stream,0))+1;

   //����������������� ����� ����� � ��������.
   timeSongDuration:=BASS_ChannelBytes2Seconds(stream, BASS_ChannelGetLength(stream,0))+1;

   //������� ������������ �� ������ � �����.
   timeCurrentPosition:=timeCurrentPosition / 86400;
   timeSongDuration:=timeSongDuration / 86400;

   //����� ������� �� ������.
   pnlCurrentTime.Caption:=FormatDateTime('hh:mm:ss', timeCurrentPosition);
   pnlSongDuration.Caption:=FormatDateTime('hh:mm:ss', timeSongDuration);

   if Bass_ChannelisActive(stream)= Bass_Active_Playing then
   begin
      BASS_ChannelGetData(stream, @FFTFata, BASS_DATA_FFT1024);
      Draw(pbEqualizer.Canvas.Handle, FFTFata, 0, -5);
   end;
end;

procedure TfMain.sbProcessBarScroll(Sender: TObject;
  ScrollCode: TScrollCode; var ScrollPos: Integer);

begin
   //��� ����������� ������ ���� � ������� ��������� ������ ������� ������ � ���������� ������� ������������ �������� � ScrollBar'e.
   if  ScrollCode = scEndScroll  then
   begin
	   Bass_ChannelSetPosition(stream, sbProcessBar.Position, 0);
	   Track:=false;
   end
   else
      //����� �������� ���������� ������������.
	   Track:=true;
end;

procedure TfMain.AddFiles(filename: string);
var
   songName: string;
begin
   //���������� ���� �� ����� � lbPrivatePlaylist.
   lbPrivatePlaylist.Items.Add(FileName);

   //�������������� �������� ����� (�������� ������� "_" � ���������� ������).
   songName:=ExtractFilename(fileName);
   songName:=StringReplace(songName, '_', ' ', [rfReplaceAll]);
   songName:=StringReplace(songName, '.mp3', '', [rfReplaceAll]);
   songName:=StringReplace(songName, '.ogg', '', [rfReplaceAll]);
   songName:=StringReplace(songName, '.aiff', '', [rfReplaceAll]);
   songName:=StringReplace(songName, '.wav', '', [rfReplaceAll]);

   //���������� �������� ����� � lbPublicPlaylist.
   lbPublicPlaylist.Items.Add(songName);

   //���� �� ��������� ������ ����, �� ��������������� ����� �� ��������� �������.
   if lbPublicPlaylist.ItemIndex=-1 then
   begin
      lbPublicPlaylist.ItemIndex:=lbPublicPlaylist.Items.Count-1;
      PlayItem;
   end;

end;

procedure TfMain.sbtnAddSongOnPlaylistClick(Sender: TObject);
begin
   //���� ���� �� ������, �� ������� �� ���������.
   if dlgOpenFile.Execute = false then
      exit;

   //����� ��������� ���������� ����� � �������� ���� ����.
   AddFiles(dlgOpenFile.FileName);
end;





procedure TfMain.PlayItem;
var
   songName: string;
begin
   //���� ������ �������������� �������, �� ���������� ����� �� ���������.
   if currentSong < 0 then exit;

   //����� �� ���� ��������� ������, ����������� �����, ���� �� ��� ����������.
   if stream <> 0 then
      Bass_StreamFree(stream);

   //�������� �����.
   stream:= Bass_streamCreateFile(false, PChar(lbPrivatePlaylist.Items.Strings[currentSong]),0,0,0);

   // ���� ���� �� ����������, �� ������� ������.
   if stream = 0 then
      ShowMessage('������ ���� �� ��������!')
   else
   begin
      //��������� ����������� �������.
		sbProcessBar.Min:=0;

      //��������� ������������ �������.
		sbProcessBar.Max:=Bass_ChannelGetLength(stream,0)-1;

      //��������� ScrollBar'a.
		sbProcessBar.Position:=0;

      //������ ����������.
      Bass_ChannelPlay(stream, false);


      //����� ����� ����� �� pnlCurrentSong.

      if Length(lbPublicPlaylist.Items.Strings[currentSong]) < 35 then
         lbCurrentSong.Caption:=lbPublicPlaylist.Items.Strings[currentSong]
      else
      begin
         songName:=lbPublicPlaylist.Items.Strings[currentSong];
         Delete(songName, 36, length(songName) - 35);
         songName:=songName+'...';
         lbCurrentSong.Caption:=songName;
      end;
      fMain.Caption:='Delayer > '+lbCurrentSong.Caption;
      lbCurrentSong.Left:=(gbCurrentSong.Width-lbCurrentSong.Width) div 2;


      sbtnPlay.Enabled:=false;
   end;
end;

procedure TfMain.sbtnDeleteSongFromPlaylistClick(Sender: TObject);
var
   InIndex:integer;

begin
   //�������� ����� ���������� �����.
   InIndex:=lbPublicPlaylist.ItemIndex;

   //������� �������� ����� �� lbPublicPlaylist.
   lbPublicPlaylist.Items.Delete(InIndex);

   //������� ���� � ����� �� lbPrivatePlaylist.
   lbPrivatePlaylist.Items.Delete(InIndex);

   if InIndex=currentSong then
      if InIndex=lbPublicPlaylist.Items.Count then
         currentSong:= lbPublicPlaylist.Items.Count-1;
   sbtnPlayClick(Sender);

   if InIndex=0 then
      Clearing;
   //��� �������� ���������� ����� ��������. ����������� ���������.
   if InIndex > lbPublicPlaylist.Items.Count - 1 then
      InIndex:=lbPublicPlaylist.Items.Count - 1;
   lbPublicPlaylist.ItemIndex:=InIndex;
end;

procedure TfMain.lbPublicPlaylistDblClick(Sender: TObject);
begin
   //��� ������� ������� �� ���� � ��������� ������������� ���.
   currentSong:=lbPublicPlaylist.ItemIndex;
   PlayItem;
end;

procedure TfMain.sbVolumeScroll(Sender: TObject;
  ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
   //������� ��������� �����.
   //�������� ���������� ������� �� 100, ��� ��� ��������� ����� 100 �������, � �������� ����� ����� �������� �� 0 �� 1.
   BASS_ChannelSetAttribute(stream,BASS_ATTRIB_VOL,sbVolume.Position/100);
end;

procedure TfMain.sbtnPreviousSongClick(Sender: TObject);
begin
   if currentSong > 0 then
      dec(currentSong)
   else
      sbtnStop.Click;
   lbPublicPlaylist.ItemIndex:=currentSong;
   sbtnPlay.Click;
end;

procedure TfMain.sbtnNextSongClick(Sender: TObject);
begin
   if sbtnShufflePlaylist.Down=true then
      ShufflePlaylist
   else
   begin
      if currentSong < lbPublicPlaylist.Count-1 then
         inc(currentSong)
      else
         currentSong:=0;
      lbPublicPlaylist.ItemIndex:=currentSong;
   end;
   sbtnPlay.Click;
end;

procedure TfMain.Draw(HWND: THandle; FFTData: TFFTData; X, Y: integer);
var
   i, YPos: longint;
   YVal : single;

begin
   pbEqualizer.Canvas.Pen.Color:=clBlack;
   pbEqualizer.Canvas.Brush.Color:=clBlack;
   pbEqualizer.Canvas.Rectangle(0, 0, pbEqualizer.Width, pbEqualizer.Height);
   for i:=0 to 127 do
   begin
      YVal:=Abs(FFTData[i]);

      YPos:=trunc((YVal)*500);

      if YPos > pbEqualizer.Height then
         YPos:=pbEqualizer.Height;

      if YPos >= FFTPeacks[i] then
         FFTPeacks[i]:=YPos
      else
         FFTPeacks[i]:=FFTPeacks[i] - 1;

      if YPos >= FFTFallOff[i] then
         FFTFallOff[i] := YPos
      else
         FFTFallOff[i] := FFTFallOff[i]-3;

      //��������� ���� �������.
      pbEqualizer.Canvas.Pen.Color:=clCream;
      pbEqualizer.Canvas.MoveTo(X+i*4, Y + pbEqualizer.Height - FFTPeacks[i]);
      pbEqualizer.Canvas.LineTo(X+i*4+3, Y + pbEqualizer.Height - FFTPeacks[i]);

      //��������� ������ ��������.
      pbEqualizer.Canvas.Pen.Color:=RGB(37,93,111);
      pbEqualizer.Canvas.Brush.Color:=RGB(37,93,111);
      pbEqualizer.Canvas.Rectangle(X+i*4, Y + pbEqualizer.Height - FFTFallOff[i], X+3+i*4, Y+pbEqualizer.Height);
   end;
end;

procedure TfMain.pbEqualizerPaint(Sender: TObject);
begin
   pbEqualizer.Canvas.Pen.Color:=clBlack;
   pbEqualizer.Canvas.Brush.Color:=clBlack;
   pbEqualizer.Canvas.Rectangle(0, 0, pbEqualizer.Width, pbEqualizer.Height);
end;

procedure TfMain.sbtnRepeatSongMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
   if sbtnRepeatSong.Down then
      sbtnRepeatSong.Down:=false
   else
      sbtnRepeatSong.Down:=true;
end;

procedure TfMain.sbtnRepeatSongClick(Sender: TObject);
begin
   if sbtnRepeatSong.Down then
      sbtnRepeatSong.Down:=false
   else
      sbtnRepeatSong.Down:=true;
end;

procedure TfMain.sbtnShufflePlaylistClick(Sender: TObject);
begin
   if sbtnShufflePLaylist.Down then
      sbtnShufflePLaylist.Down:=false
   else
      sbtnShufflePLaylist.Down:=true;
end;



procedure TfMain.WmDropFiles(var Msg: TWMDropFiles);
var
	CFileName: array[0..MAX_Path] of Char;
begin
	try
		if DragQueryFile(Msg.Drop, 0, CfileName, MaX_Path)>0 then
		begin
			AddFiles(CFileName);
			Msg.Result:=0;
		end;
	finally
		DragFinish(msg.Drop);
	end;
end;


procedure TfMain.ShufflePlaylist;
var
   temp: integer;
begin
   randomize;
   temp:=random(lbPublicPlaylist.Items.Count);
   if temp=currentSong then
      if temp=0 then
         currentSong:=temp+1
      else
         currentSong:=temp-1
   else
      currentSong:=temp;
end;



procedure TfMain.sbtnShufflePlaylistMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
     if sbtnShufflePLaylist.Down then
      sbtnShufflePLaylist.Down:=false
   else
      sbtnShufflePLaylist.Down:=true;
end;

procedure TfMain.Clearing;
begin
   pbEqualizerPaint(Self);
   BASS_StreamFree(Stream);
   fMain.Caption:='   Delayer';
   lbCurrentSong.Caption:='';
end;

end.
