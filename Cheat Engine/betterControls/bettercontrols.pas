unit betterControls;

{$mode delphi}

interface

uses
  windows,Classes, SysUtils, newRadioButton, newCheckBox, newButton, newListView,
  newEdit, newMainMenu, newForm, newListBox, newProgressBar, newMemo, newComboBox,
  newGroupBox, newSpeedButton, newTreeView, newHeaderControl, newScrollBar,
  newScrollBox, newSynEdit, newPageControl, newtabcontrol, newStatusBar,
  newCheckListBox, newCheckGroup, newColorBox, newDirectoryEdit,
  Graphics, Themes, UxTheme, bettercontrolColorSet;

type
  TButton=class(TNewButton);
  TCheckBox=class(TNewCheckBox);
  TRadioButton=class(TNewRadioButton);
  TListView=class(TNewListView);
  TEdit=class(TNewEdit);
  TMainMenu=class(TNewMainMenu);
  TMenuItem=class(TNewMenuItem);
  TForm=class(TNewForm);
  TListBox=class(TNewListBox);
  TProgressBar=class(TNewProgressbar);
  TMemo=class(TNewMemo);
  TComboBox=class(TNewComboBox);
  TGroupBox=class(TNewGroupBox);
  TSpeedButton=class(TNewSpeedButton);
  TTreeview=class(TNewTreeView);
  THeaderControl=class(TNewHeaderControl);
  TScrollBar=class(TNewScrollBar);
  TScrollBox=class(TNewScrollBox);
  TSynEdit=class(TNewSynEdit);
  TPageControl=class(TNewPageControl);
  TTabControl=class(TNewTabControl);
  TStatusBar=class(TNewStatusBar);
  TCheckListbox=class(TNewCheckListBox);
  TCheckGroup=class(TNewCheckGroup);  //not fully yet (too limited)
  TColorBox=class(TNewColorBox);
  TDirectoryEdit=class(TNewDirectoryEdit);

var
  globalCustomDraw: boolean;
  currentColorSet: TBetterControlColorSet;

  ColorSet: TBetterControlColorSet; //set based on querying the system

  //color overrides
  clWindowtext: TColor=graphics.clWindowText;
  clWindow: TColor=graphics.clWindow;
  clHighlight: TColor=graphics.clHighlight;
  clBtnFace: TColor=graphics.clBtnFace;
  clBtnText: TColor=graphics.clBtnText;

  darkmodestring: string=''; //contains ' dark' if darkmode is used (used for settings)


type
  TAllowDarkModeForWindow = function(hwnd: HWND; state: DWORD): BOOL; stdcall;
  TAllowDarkModeForApp = function(state: integer): BOOL; stdcall;
  TFlushMenuThemes = procedure; stdcall;
  TRefreshImmersiveColorPolicyState = procedure; stdcall;
  TShouldAppsUseDarkMode = function: BOOL; stdcall;


var
  RefreshImmersiveColorPolicyState: TRefreshImmersiveColorPolicyState;
  AllowDarkModeForWindow: TAllowDarkModeForWindow;
  AllowDarkModeForApp: TAllowDarkModeForApp;
  FlushMenuThemes: TFlushMenuThemes;
  _ShouldAppsUseDarkMode: TShouldAppsUseDarkMode;

  function incColor(c: tcolor; amount: integer): tcolor;
  procedure registerDarkModeHintHandler;
  function ShouldAppsUseDarkMode:BOOL;

implementation

uses forms, controls, Registry;

var
  FHandle: THandle;
  FLoaded: Boolean;
  darkmodebuggy: boolean;

function inccolor(c: Tcolor; amount: integer): tcolor;
var  R, G, B : Byte;
begin
  RedGreenBlue(ColorToRGB(c), R, G, B);
  R := min(255, Integer(R) + amount);
  G := min(255, Integer(G) + amount);
  B := min(255, Integer(B) + amount);
  Result := RGBToColor(R, G, B);
end;

procedure RefreshImmersiveColorPolicyState_stub; stdcall;
begin
end;

function AllowDarkModeForWindow_stub(hwnd: HWND; state: DWORD): BOOL; stdcall;
begin
  exit(false);
end;

function AllowDarkModeForApp_stub(state: integer): BOOL; stdcall;
begin
  exit(false);
end;

var UsesDarkMode: (dmUnknown, dmYes, dmNo)=dmUnknown;

function ShouldAppsUseDarkMode:BOOL; stdcall;
var reg: tregistry;
begin
  if darkmodebuggy then exit(false);

  if UsesDarkMode=dmUnknown then
  begin


    reg:=TRegistry.Create;
    reg.RootKey:=HKEY_CURRENT_USER;
    if reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',false) then
    begin
      if reg.ValueExists('AppsUseLightTheme') then
      begin
        if reg.ReadInteger('AppsUseLightTheme')=0 then
          UsesDarkMode:=dmYes
        else
          UsesDarkMode:=dmNo;
      end;


      if UsesDarkMode=dmUnknown then
      begin
        if reg.ValueExists('SystemUsesLightTheme') then
        begin
          if reg.ReadInteger('SystemUsesLightTheme')=0 then
            UsesDarkMode:=dmYes
          else
            UsesDarkMode:=dmNo;
        end;
      end;
    end;

    reg.free;

    if UsesDarkMode=dmUnknown then
    begin
      UsesDarkMode:=dmNo;
      if assigned(_ShouldAppsUseDarkMode) then
      begin
        if _ShouldAppsUseDarkMode() then
          UsesDarkMode:=dmYes;
      end;
    end;
  end;

  exit(UsesDarkMode=dmyes);
end;


type
  TBCHintHandler=class
  private
    procedure ShowHintEvent(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
  end;

procedure TBCHintHandler.ShowHintEvent(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
begin
  if ShouldAppsUseDarkMode then
    HintInfo.HintColor:=ColorSet.TextBackground;
end;

procedure registerDarkModeHintHandler;
var hh: TBCHintHandler;
begin
  hh:=TBCHintHandler.Create;
  application.AddOnShowHintHandler(hh.ShowHintEvent);
end;

var
  c: TColorRef;
  theme: THandle;

initialization
  //setup ColorSet

  ColorSet.FontColor:=clWindowtext;
  colorset.TextBackground:=clWindow;


  darkmodebuggy:=true;
  try
    currentColorSet:=ColorSet;

    FHandle := LoadLibrary('uxtheme.dll');
    if FHandle<>0 then
    begin
      @RefreshImmersiveColorPolicyState := GetProcAddress(FHandle, MakeIntResource(104));
      @AllowDarkModeForWindow := GetProcAddress(FHandle, MakeIntResource(133));
      @AllowDarkModeForApp := GetProcAddress(FHandle, MakeIntResource(135));
      @FlushMenuThemes := GetProcAddress(FHandle, MakeIntResource(136));
      @_ShouldAppsUseDarkMode := GetProcAddress(FHandle, MakeIntResource(132));
    end;

    if not assigned(RefreshImmersiveColorPolicyState) then RefreshImmersiveColorPolicyState:=@RefreshImmersiveColorPolicyState_stub;
    if not assigned(AllowDarkModeForWindow) then AllowDarkModeForWindow:=@AllowDarkModeForWindow_stub;
    if not assigned(AllowDarkModeForApp) then AllowDarkModeForApp:=@AllowDarkModeForApp_stub;
    if not assigned(FlushMenuThemes) then FlushMenuThemes:=@RefreshImmersiveColorPolicyState_stub;

    AllowDarkModeForApp(1);  //3 is disable, 2=force on, 1=system default


    FlushMenuThemes;
    RefreshImmersiveColorPolicyState;

    darkmodebuggy:=false;

    theme:=OpenThemeData(0,'ItemsView');
    if theme<>0 then
    begin
      GetThemeColor(theme, 0,0,TMT_TEXTCOLOR,ColorSet.FontColor);
      GetThemeColor(theme, 0,0,TMT_FILLCOLOR,ColorSet.TextBackground);
      colorset.InactiveFontColor:=ColorSet.FontColor xor $aaaaaa;
      ColorSet.ButtonBorderColor:=deccolor(ColorSet.FontColor,10);

      clwindowText:=ColorSet.FontColor;

      CloseThemeData(theme);

      if ShouldAppsUseDarkMode() then
      begin
        ColorSet.CheckboxFillColor:=$e8e8e8;
        ColorSet.InactiveCheckboxFillColor:=$999999;
        clBtnFace:=inccolor(ColorSet.TextBackground,8);
        clBtnText:=ColorSet.FontColor;

        clWindow:=colorset.TextBackground;

        ColorSet.CheckboxCheckMarkColor:=InvertColor(ColorSet.CheckboxFillColor);
        ColorSet.InactiveCheckboxCheckMarkColor:=InvertColor(ColorSet.CheckboxCheckMarkColor);

        darkmodestring:=' dark';
      end;
    end;



  except

  end;
end.

