unit FindAllFilesEnhanced;
// An enhanced version of the FPC FindAllFiles routine that will detect hidden files
// and hidden files inside hidden directories. Credit to users EngKin and Bart from
// the forums for quickly developing this unit

{$mode objfpc}{$H+} // {$H+} ensures strings are of unlimited size

interface
uses
  LazUTF8Classes, Classes;

function FindAllFilesEx(const SearchPath: string; SearchMask: string;
    SearchSubDirs: boolean; IncludeHiddenDirs: boolean): TStringListUTF8;

implementation
uses
  FileUtil,
  SysUtils;  //for faHidden

type
  { TListFileSearcher }

  TListFileSearcher = class(TFileSearcher)
  private
    FList: TStrings;
  protected
    procedure DoFileFound; override;
  public
    constructor Create(AList: TStrings);
  end;

{ TListFileSearcher }

procedure TListFileSearcher.DoFileFound;
begin
  FList.Add(FileName);
end;

constructor TListFileSearcher.Create(AList: TStrings);
begin
  inherited Create;
  FList := AList;
end;

function FindAllFilesEx(const SearchPath: string; SearchMask: string;
  SearchSubDirs: boolean; IncludeHiddenDirs: boolean): TStringListUTF8;
var
  Searcher: TListFileSearcher;
begin
  Result   := TStringListUTF8.Create;
  Searcher := TListFileSearcher.Create(Result);
  Searcher.DirectoryAttribute := Searcher.DirectoryAttribute or faHidden;
  try
    Searcher.Search(SearchPath, SearchMask, SearchSubDirs);
  finally
    Searcher.Free;
  end;
end;

end.

