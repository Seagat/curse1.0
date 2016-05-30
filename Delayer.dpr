program Delayer;

uses
  Forms,
  mp3player in 'mp3player.pas' {fMain};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.
