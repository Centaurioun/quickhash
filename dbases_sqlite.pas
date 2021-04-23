unit dbases_sqlite; // New to v3.0.0 of QuickHash

{$mode objfpc}{$H+} // {$H+} ensures all strings are of unlimited size, and set as ansistring

interface

uses
{$ifdef Linux}
  dl,
{$endif}
{$ifdef Darwin}
  dl,
{$endif}
  Classes, SysUtils, db, sqldb, sqldblib, fpcsvexport, sqlite3conn, FileUtil,
  LResources, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, DBGrids,
  sqlite3dyn, clipbrd, DbCtrls, LazUTF8, LazUTF8Classes;

type

  { TfrmSQLiteDBases }

  TfrmSQLiteDBases = class(TForm)
    CSVExporter1: TCSVExporter; // We use this for users who want to clipboard the results. Works fine if not too many values.
    DataSource1: TDataSource;
    DataSource2: TDataSource;
    DataSource3: TDataSource;
    lblConnectionStatus: TLabel;
    SQLDBLibraryLoaderLinux: TSQLDBLibraryLoader;
    SQLDBLibraryLoaderOSX: TSQLDBLibraryLoader;
    SQLDBLibraryLoaderWindows: TSQLDBLibraryLoader;
    SQLite3Connection1: TSQLite3Connection;
    sqlFILES: TSQLQuery;
    sqlCOPY: TSQLQuery;
    sqlCOMPARETWOFOLDERS : TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure CreateDatabase(DBaseName : string);
    procedure WriteFILESValuesToDatabase(Filename, Filepath, HashValue, FileSize : string; KnownHash : boolean);
    procedure WriteCOPYValuesToDatabase(Col1, Col2, Col3, Col4, Col5 : string);
    procedure Write_INSERT_All_Rows_Required(RowCount : integer);
    procedure Write_COMPARE_TWO_FOLDERS_FolderA(Col1, Col2 : string; Counter : integer);
    procedure Write_COMPARE_TWO_FOLDERS_FolderB(Col3, Col4 : string; Counter : integer);
    procedure EmptyDBTable(TableName : string; DBGrid : TDBGrid);
    procedure EmptyDBTableCOPY(TableName : string; DBGrid : TDBGrid);
    procedure EmptyDBTableC2F(TableName : string; DBGrid : TDBGrid);
    procedure UpdateGridFILES(Sender: TObject);
    procedure UpdateGridCOPYTAB(Sender: TObject);
    procedure UpdateGridCOMPARETWOFOLDERSTAB(Sender: TObject);
    procedure SaveDBToCSV(DBGrid : TDBGrid; Filename : string);
    procedure SaveC2FDBToCSV(DBGrid : TDBGrid; Filename : string);
    procedure SaveFILESTabToHTML(DBGrid : TDBGrid; Filename : string);
    procedure SaveCOPYWindowToHTML(DBGrid : TDBGrid; Filename : string);
    procedure SaveC2FWindowToHTML(DBGrid : TDBGrid; Filename : string);
    procedure DatasetToClipBoard(DBGrid : TDBGrid);
    procedure ShowDuplicates(DBGrid : TDBGrid);
    procedure DeleteDuplicates(DBGrid : TDBGrid);
    procedure SortByID(DBGrid : TDBGrid);
    procedure SortByFileName(DBGrid : TDBGrid);
    procedure SortByFilePath(DBGrid : TDBGrid);
    procedure SortByHash(DBGrid : TDBGrid);
    procedure SortByHashList(DBGrid : TDBGrid);
    procedure FilterOutHashListNO(DBGrid : TDBGrid);
    procedure FilterOutHashListYES(DBGrid : TDBGrid);
    procedure ShowAll(DBGrid : TDBGrid);
    procedure ShowAllCOPYGRID(DBGrid : TDBGrid);
    procedure ShowAllC2FGRID(DBGrid : TDBGrid);
    procedure CopyFileNameOfSelectedCell(DBGrid : TDBGrid);
    procedure CopyFilePathOfSelectedCell(DBGrid : TDBGrid);
    procedure CopyHashOfSelectedCell(DBGrid : TDBGrid);
    procedure CopyAllHashesFILESTAB(DBGrid : TDBGrid; UseFileFlag : Boolean);
    procedure CopySelectedRowFILESTAB(DBGrid : TDBGrid);
    procedure CopySelectedRowCOPYTAB(DBGrid : TDBGrid);
    procedure CopySelectedRowC2FTAB(DBGrid : TDBGrid);
    procedure SortBySourceFilename(DBGrid : TDBGrid);
    procedure SortByDestinationFilename(DBGrid : TDBGrid);
    procedure SortBySourceHash(DBGrid : TDBGrid);
    procedure SortByDestinationHash(DBGrid : TDBGrid);
    procedure ShowMismatchesC2F(DBGrid : TDBGrid);
    function CountGridRows(DBGrid : TDBGrid) : integer;

  private
    { private declarations }
  public
    DBName : string; // Used by PreserveDB button globally to enable the user to save the DB. New as of v3.3.0
    { public declarations }
  const
    // More information on the use of these values is below.
    // They need not be set as constants and can be any valid value
    application_id = 1189021115; // must be a 32-bit Unsigned Integer (Longword 0 .. 4294967295)  https://www.sqlite.org/pragma.html#pragma_application_id
    user_version = 23400001;     // must be a 32-bit Signed Integer (LongInt -2147483648 .. 2147483647)  https://www.sqlite.org/pragma.html#pragma_user_version
  end;

var
  frmSQLiteDBases: TfrmSQLiteDBases;

implementation

{$R *.lfm}

{ TfrmSQLiteDBases }

  uses
    Unit2, uDisplayGrid, udisplaygrid3;

// On creation we check for SQLite capability and load as we find it.
// If it cant be found, QH will run with some tabs, but not those that need SQLIte backend
procedure TfrmSQLiteDBases.FormCreate(Sender: TObject);
var
  guid : TGuid;
  SQLiteLibraryPath, strFileNameRandomiser, SafePlaceForDB : string;
  {$ifdef Linux}
    LibHandle : Pointer;
    Pdlinfo : Pdl_info;
    PtrSQLiteLibraryPath : PChar;
  {$endif}
  {$ifdef darwin}
     LibHandle : THandle = Default(THandle);
  {$endif}
begin
  // Initiate calls to SQLite libraries for WINDOWS
  {$ifdef windows}
  SQLDBLibraryLoaderWindows.ConnectionType := 'SQLite3';
    {$ifdef CPU32}
      SQLiteLibraryPath := 'sqlite3-win32.dll';
    {$else ifdef CPU64}
      SQLiteLibraryPath := 'sqlite3-win64.dll';
    {$endif}

  if FileExists(SQLiteLibraryPath) then
  begin
   SQLDBLibraryLoaderWindows.LibraryName := SQLiteLibraryPath;
   SQLDBLibraryLoaderWindows.Enabled := true;
   SQLDBLibraryLoaderWindows.LoadLibrary;

   if CreateGUID(guid) = 0 then
   begin
     strFileNameRandomiser := GUIDToString(guid);
   end
   else
     begin
       strFileNameRandomiser := FormatDateTime('YYYY-MM-DD_HH-MM-SS.ZZZ', Now);
     end;
   // write the SQLite database file to system temp
   SafePlaceForDB := GetTempDir;
   if ForceDirectories(SafePlaceForDB) then
   begin
     SQLite3Connection1.DatabaseName := SafePlaceForDB + 'QuickHashDB_' + strFileNameRandomiser + '.sqlite';
     // Create the database
     CreateDatabase(SQLite3Connection1.DatabaseName);
     if SQLIte3Connection1.Connected then
     begin
       lblConnectionStatus.Caption:= 'SQLite3 Database connection active';
       DBName := SQLite3Connection1.DatabaseName;  // We call DBName from Unit2, that is why it is declared here
     end;
   end
   else
     begin
       Showmessage('Could not create folder ' + SafePlaceForDB + ' for ' + SQLite3Connection1.DatabaseName);
     end;
  end
  else
   begin
     ShowMessage('Cannot create SQLite database. Probably SQLite libraries are not on your system.');
     MainForm.TabSheet3.Enabled := false; // disable FileS tab, because it needs SQLite
     MainForm.TabSheet4.Enabled := false; // disable Copy tab, because it needs SQLite
   end;
  {$endif} // End of Windows compiler directive

  // Initiate calls to SQLite libraries for LINUX
  {$ifdef linux}
  SQLDBLibraryLoaderLinux.ConnectionType := 'SQLite3';
  SQLiteLibraryPath := '';
  LibHandle := dlopen('libsqlite3.so.0', RTLD_LAZY);
  if LibHandle <> nil then
  begin
    Pdlinfo := LibHandle;
    PtrSQLiteLibraryPath := Pdlinfo^.dli_fbase;
    SQLiteLibraryPath := String(PtrSQLiteLibraryPath);
    PtrSQLiteLibraryPath := nil;
    dlclose(LibHandle);
  end;

  if FileExists(SQLiteLibraryPath) then
  begin
  SQLDBLibraryLoaderLinux.LibraryName := SQLiteLibraryPath;
  SQLDBLibraryLoaderLinux.Enabled := true;
  SQLDBLibraryLoaderLinux.LoadLibrary;
  if CreateGUID(guid) = 0 then
   begin
     strFileNameRandomiser := GUIDToString(guid);
   end
   else
     begin
       strFileNameRandomiser := FormatDateTime('YYYY-MM-DD_HH-MM-SS.ZZZ', Now);
     end;
   // write the SQLite database file to system temp
   SafePlaceForDB := GetTempDir;
   if ForceDirectories(SafePlaceForDB) then
   begin
     SQLite3Connection1.DatabaseName := SafePlaceForDB + 'QuickHashDB_' + strFileNameRandomiser + '.sqlite';
     // Create the database
     CreateDatabase(SQLite3Connection1.DatabaseName);
     if SQLIte3Connection1.Connected then
     begin
       lblConnectionStatus.Caption:= 'SQLite3 Database connection active';
       DBName := SQLite3Connection1.DatabaseName;  // We call DBName from Unit2, that is why it is declared here
     end;
   end
   else
     begin
       Showmessage('Could not create folder ' + SafePlaceForDB + ' for ' + SQLite3Connection1.DatabaseName);
     end;
  end
  else
   begin
     ShowMessage('Cannot create SQLite database. Probably SQLite libraries are not on your system.');
     MainForm.TabSheet3.Enabled := false; // disable FileS tab, because it needs SQLite
     MainForm.TabSheet4.Enabled := false; // disable Copy tab, because it needs SQLite
   end;
  {$endif}   // End of Linux compiler directive

  // Initiate calls to SQLite libraries for APPLE OSX
  {$ifdef darwin}
  // Thanks to OSX being a total and utter pain, moving goal posts with every release of OSX,
  // and since BigSur has removed libraries, more Skullduggery is required for
  // that platform. Thanks Apple, from me.
  SQLDBLibraryLoaderOSX.ConnectionType := 'SQLite3';
  SQLiteLibraryPath := '';

  // First check the SQLite lib can be loaded by calling the new dynamic cache of Big Sur
  LibHandle := loadLibrary(PChar('libsqlite3.dylib'));

  // check whether loading was possible and successful but then just unload it
  // to allow the TSQLDBLibraryLoader to load it, later
  if LibHandle <> 0 then
    begin
      // Nothing is needed here anymore
    end
  else ShowMessage('Cannot load SQLite libraries for backend use.' + SysErrorMessage(GetLastOSError));

  // unload library and pass control to TSQLDBLibraryLoader
  if LibHandle <> NilHandle then
    begin
      unloadLibrary(LibHandle);
      SQLDBLibraryLoaderOSX.LibraryName := 'libsqlite3.dylib';
      SQLDBLibraryLoaderOSX.Enabled := true;
      SQLDBLibraryLoaderOSX.LoadLibrary;

      // Generate a unique name for the DB
      if CreateGUID(guid) = 0 then
      begin
        strFileNameRandomiser := GUIDToString(guid);
      end
      else
        begin
          strFileNameRandomiser := FormatDateTime('YYYY-MM-DD_HH-MM-SS.ZZZ', Now);
        end;

      // write the SQLite database file to system temp
      SafePlaceForDB := GetTempDir;
      if ForceDirectories(SafePlaceForDB) then
      begin
        SQLite3Connection1.DatabaseName := SafePlaceForDB + 'QuickHashDB_' + strFileNameRandomiser + '.sqlite';
        // Create the database
        CreateDatabase(SQLite3Connection1.DatabaseName);
        if SQLIte3Connection1.Connected then
        begin
          lblConnectionStatus.Caption:= 'SQLite3 Database connection active';
          DBName := SQLite3Connection1.DatabaseName;  // We call DBName from Unit2, that is why it is declared here
        end;
      end
    end;

  LibHandle := NilHandle;

  // Method used prior to v3.3.0, for info
   { SQLDBLibraryLoaderOSX.ConnectionType := 'SQLite3';
    SQLiteLibraryPath := '';
    LibHandle := dlopen('libsqlite3.dylib', RTLD_LAZY);
    if LibHandle <> nil then
    begin
      Pdlinfo := LibHandle;
      PtrSQLiteLibraryPath := Pdlinfo^.dli_fbase;
      SQLiteLibraryPath := String(PtrSQLiteLibraryPath);
      PtrSQLiteLibraryPath := nil;
      dlclose(LibHandle);
    end;}
  {$endif} // End of Apple OSC compiler directive
end;


// Create a fresh SQLite database for each instance of the program
procedure TfrmSQLiteDBases.CreateDatabase(DBaseName : string);
begin
  SQLite3Connection1.Close; // Ensure the connection is closed when we start
  try
    // Since we're making this database for the first time,
    // check whether the file already exists
    if FileExists(SQLite3Connection1.DatabaseName) then
    begin
      DeleteFile(SQLite3Connection1.DatabaseName);
    end;
    // Make a new database and add the tables
    try
      SQLite3Connection1.Open;
      SQLTransaction1.Active := true;

      // Periodically sort the database out to ensure it stays in tip top shape
      // during heavy usage
      SQLite3Connection1.ExecuteDirect('PRAGMA auto_vacuum = FULL;');

      // Per the SQLite Documentation (edited for clarity):
      // The pragma user_version is used to set or get the value of the user-version.
      // The user-version is a big-endian 32-bit signed integer stored in the database header at offset 60.
      // The user-version is not used internally by SQLite. It may be used by applications for any purpose.
      // http://www.sqlite.org/pragma.html#pragma_schema_version
      SQLite3Connection1.ExecuteDirect('PRAGMA user_version = ' + IntToStr(user_version) + ';');

      // Per the SQLite Documentation:
      // The application_id PRAGMA is used to query or set the 32-bit unsigned big-endian
      // "Application ID" integer located at offset 68 into the database header.
      // Applications that use SQLite as their application file-format should set the
      // Application ID integer to a unique integer so that utilities such as file(1) can
      // determine the specific file type rather than just reporting "SQLite3 Database".
      // A list of assigned application IDs can be seen by consulting the magic.txt file
      // in the SQLite source repository.
      // http://www.sqlite.org/pragma.html#pragma_application_id
      SQLite3Connection1.ExecuteDirect('PRAGMA application_id = ' + IntToStr(application_id) + ';');

      // Here we're setting up a table named "TBL_FILES" in the new database for FileS tab
      // Note AUTOINCREMENT is NOT used! If it is, it causes problems with RowIDs etc after multiple selections
      // Besides, SQLite advice is not to use it unless entirely necessary (http://sqlite.org/autoinc.html)
      // VARCHAR is set as 32767 to ensure max length of NFTS based filename and paths can be utilised
      SQLite3Connection1.ExecuteDirect('CREATE TABLE "TBL_FILES"('+
                  ' "id" Integer NOT NULL PRIMARY KEY,'+
                  ' "FileName" VARCHAR(32767) NOT NULL,'+
                  ' "FilePath" VARCHAR(32767) NOT NULL,'+
                  ' "HashValue" VARCHAR NOT NULL,'+
                  ' "FileSize" VARCHAR NULL,'+
                  ' "KnownHashFlag" VARCHAR NULL);');
      // Creating an index based upon id in the TBL_FILES Table
      SQLite3Connection1.ExecuteDirect('CREATE UNIQUE INDEX "FILES_id_idx" ON "TBL_FILES"( "id" );');

      // Here we're setting up a table named "TBL_COPY" in the new database for Copy tab
      // VARCHAR is set as 32767 to ensure max length of NFTS based filename and paths can be utilised
      SQLite3Connection1.ExecuteDirect('CREATE TABLE "TBL_COPY"('+
                  ' "id" Integer NOT NULL PRIMARY KEY,'+
                  ' "SourceFilename" VARCHAR(32767) NOT NULL,'+
                  ' "SourceHash" VARCHAR NULL,'+
                  ' "DestinationFilename" VARCHAR(32767) NOT NULL,'+
                  ' "DestinationHash" VARCHAR NULL,'+
                  ' "DateAttributes" VARCHAR NULL);');
      // Creating an index based upon id in the TBL_COPY Table
      SQLite3Connection1.ExecuteDirect('CREATE UNIQUE INDEX "COPIED_FILES_id_idx" ON "TBL_COPY"( "id" );');

      // New to v3.2.0 to enable a display grid for the comparison of two folders
      // Here we're setting up a table named "TBL_COMPARE_TWO_FOLDERS" in the new database for Comapre Two Folders tab
      // VARCHAR is set as 32767 to ensure max length of NFTS based filename and paths can be utilised
      SQLite3Connection1.ExecuteDirect('CREATE TABLE "TBL_COMPARE_TWO_FOLDERS"('+
                  ' "id" Integer NOT NULL PRIMARY KEY,'+
                  ' "FolderAndFileNameA" VARCHAR(32767) NULL,'+
                  ' "FolderAndFileNameAHash" VARCHAR NULL,'+
                  ' "FolderAndFileNameB" VARCHAR(32767) NULL,'+
                  ' "FolderAndFileNameBHash" VARCHAR NULL);');
      // Creating an index based upon id in the TBL_COMPARE_TWO_FOLDERS Table
      SQLite3Connection1.ExecuteDirect('CREATE UNIQUE INDEX "COMPARE_TWO_FOLDERS_id_idx" ON "TBL_COMPARE_TWO_FOLDERS"( "id" );');

      // Now write to the new database
      SQLTransaction1.CommitRetaining;
    except
      ShowMessage('SQLite detected but unable to create a new SQLite Database');
    end;
  except
    ShowMessage('SQLite detected but could not check if a database file exists');
  end;
end;

// I've spent what seems like half my life working out how to copy the entire selected
// row of a DBGrid component without success!! So I resorted to childhood logic.
// Anyone who knows of a better way, let me know!
procedure TfrmSQLiteDBases.CopySelectedRowFILESTAB(DBGrid : TDBGrid);
var
  FileNameCell, FilePathCell, FileHashCell, AllRowCells : string;
begin
  // Get the data from the filename cell that the user has selected
  FileNameCell := DBGrid.DataSource.DataSet.Fields[1].Value;
  // Get the data from the filepath cell that the user has selected
  FilePathCell := DBGrid.DataSource.DataSet.Fields[2].Value;
  // Get the data from the filehash cell that the user has selected
  FileHashCell := DBGrid.DataSource.DataSet.Fields[3].Value;
  // and just add them all together :-)
  AllRowCells := FileNameCell + ',' + FilePathCell + ',' + FileHashCell;
  Clipboard.AsText := AllRowCells;
end;

procedure TfrmSQLiteDBases.CopySelectedRowCOPYTAB(DBGrid : TDBGrid);
var
  AllRowCells, SourceFileNameCell, SourceHash,
    DestinationFilenameCell, DestinationHash, DateAttr : string;
begin
  // Get the data from the source filename cell that the user has selected
  SourceFileNameCell := DBGrid.DataSource.DataSet.Fields[1].Value;
  // Get the source file hash cell that the user has selected
  SourceHash := DBGrid.DataSource.DataSet.Fields[2].Value;
  // Get the destination filename
  DestinationFilenameCell := DBGrid.DataSource.DataSet.Fields[3].Value;
  // Get the destination hash
  DestinationHash  := DBGrid.DataSource.DataSet.Fields[4].Value;
  // Get the date attributes
  DateAttr         := DBGrid.DataSource.DataSet.Fields[5].Value;
  // and just add them all together :-)
  AllRowCells := SourceFileNameCell + ',' + SourceHash  + ',' + DestinationFilenameCell + ',' + DestinationHash + ',' + DateAttr;
  Clipboard.AsText := AllRowCells;
end;

// Copies selected row to clipboard of "Compare Two Folders" tab
procedure TfrmSQLiteDBases.CopySelectedRowC2FTAB(DBGrid : TDBGrid);
var
  AllRowCells, FolderAFileNameCell, FolderAFileHash,
    FolderBFileNameCell, FolderBFileHash : string;
begin
  // Get the data from the source filename cell that the user has selected
  FolderAFileNameCell := DBGrid.DataSource.DataSet.Fields[1].Value;
  // Get the source file hash cell that the user has selected
  FolderAFileHash := DBGrid.DataSource.DataSet.Fields[2].Value;
  // Get the destination filename
  FolderBFileNameCell := DBGrid.DataSource.DataSet.Fields[3].Value;
  // Get the destination hash
  FolderBFileHash  := DBGrid.DataSource.DataSet.Fields[4].Value;
  // and just add them all together :-)
  AllRowCells := FolderAFileNameCell + ',' + FolderAFileHash  + ',' + FolderBFileNameCell + ',' + FolderBFileHash;
  Clipboard.AsText := AllRowCells;
end;

// Counts rows of current DBGrid. Returns positive integer if successfull and
// returns active display to top row
function TfrmSQLiteDBases.CountGridRows(DBGrid : TDBGrid) : integer;
var
  NoOfRows : integer;
begin
  result := -1;
  NoOfRows := -1;
  DBGrid.DataSource.Dataset.DisableControls;
  DBGrid.DataSource.DataSet.First;
  while not DBGrid.DataSource.DataSet.EOF do
  begin
    inc(NoOfRows, 1);
    DBGrid.DataSource.DataSet.Next;
  end;
  DBGrid.DataSource.Dataset.EnableControls;
  // Go to top of grid.
  DBGrid.DataSource.DataSet.First;
  // Return count
  If NoOfRows > -1 then result := NoOfRows;
end;
// Saves the grid in FILES tab to HTML. If small volume of records, uses a stringlist.
// If big volume, uses file stream.
procedure TfrmSQLiteDBases.SaveFILESTabToHTML(DBGrid : TDBGrid; Filename : string);
var
  strTitle, FileNameCell, FilePathCell, FileHashCell : string;
  NoOfRowsInGrid : integer;
  sl             : TStringList;
  fs             : TFileStreamUTF8;

  const
    strHTMLHeader      = '<HTML>'  ;
    strTITLEHeader     = '<TITLE>QuickHash HTML Output' ;
    strBODYHeader      = '<BODY>'  ;
    strTABLEHeader     = '<TABLE>' ;
    strTABLEROWStart   = '<TR>'    ;
    strTABLEDATAStart  = '<TD>'    ;
    strTABLEDataEnd    = '</TD>'   ;
    strTABLEROWEnd     = '</TR>'   ;
    strTABLEFooter     = '</TABLE>';
    strBODYFooter      = '</BODY>' ;
    strTITLEFooter     = '</TITLE>';
    strHTMLFooter      = '</HTML>' ;

begin
  NoOfRowsInGrid := -1;
  // If database volume not too big, use memory and stringlists. Otherwise, use file writes
  if DBGrid.Name = 'RecursiveDisplayGrid1' then
    begin
      NoOfRowsInGrid := CountGridRows(DBGrid);// Count the rows first. If not too many, use memory. Otherwise, use filestreams
      if (NoOfRowsInGrid < 10000) and (NoOfRowsInGrid > -1) then
      try
        MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
        Application.ProcessMessages;
        // Write the grid to a stringlist
        sl := TStringList.Create;
        sl.add('<HTML>');
        sl.add('<TITLE>QuickHash HTML Output</TITLE>');
        sl.add('<BODY>');
        sl.add('<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>');
        sl.add('<TABLE>');
        DBGrid.DataSource.DataSet.DisableControls;
        DBGrid.DataSource.DataSet.First;
        while not DBGrid.DataSource.DataSet.EOF do
          begin
            sl.add('<tr>');
            // Get the data from the filename cell that the user has selected
            FileNameCell := DBGrid.DataSource.DataSet.Fields[1].Value;
            sl.add('<td>'+FileNameCell+'</td>');
            // Get the data from the filepath cell that the user has selected
            FilePathCell := DBGrid.DataSource.DataSet.Fields[2].Value;
            sl.add('<td>'+FilePathCell+'</td>');
            // Get the data from the filehash cell that the user has selected
            FileHashCell := DBGrid.DataSource.DataSet.Fields[3].Value;
            sl.add('<td>'+FileHashCell+'</td>');
            sl.add('</tr>');
            DBGrid.DataSource.DataSet.Next;
          end;
        sl.add('</TABLE>');
        sl.add('</BODY> ');
        sl.add('</HTML> ');
        DBGrid.DataSource.DataSet.EnableControls;
        sl.SaveToFile(Filename);
      finally
        sl.free;
        MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
        Application.ProcessMessages;
      end
      else // Use filestream method because there's more than 10K rows. Too many to add HTML tags and store in memory
        try
        if not FileExists(filename) then
          begin
            fs := TFileStreamUTF8.Create(Filename, fmCreate);
          end
        else fs := TFileStreamUTF8.Create(Filename, fmOpenReadWrite);

        MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
        strTitle := '<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>';
        Application.ProcessMessages;

        fs.Write(strHTMLHeader[1], Length(strHTMLHeader));
        fs.Write(#13#10, 2);
        fs.Write(strTITLEHeader[1], Length(strTITLEHeader));
        fs.Write(strTITLEFooter[1], Length(strTITLEFooter));
        fs.Write(#13#10, 2);
        fs.Write(strBODYHeader[1], Length(strBODYHeader));
        fs.Write(strTitle[1], Length(strTitle));
        fs.Write(#13#10, 2);
        fs.Write(strTABLEHeader[1], Length(strTABLEHeader));

        { strTABLEROWStart   = '<TR>'      = 4 bytes
          strTABLEDATAStart  = '<TD>'      = 4 bytes
          strTABLEDataEnd    = '</TD>'     = 5 bytes
          strTABLEROWEnd     = '</TR>'     = 5 bytes
          strTABLEFooter     = '</TABLE>'  = 8 bytes
          strBODYFooter      = '</BODY>'   = 7 bytes
          strTITLEFooter     = '</TITLE>'  = 8 bytes
          strHTMLFooter      = '</HTML>'   = 7 bytes}
        DBGrid.DataSource.DataSet.DisableControls;
        DBGrid.DataSource.DataSet.First;
        while not DBGrid.DataSource.DataSet.EOF do
        begin
          // Start new row
          fs.Write(strTABLEROWStart[1], 4);
          // Get the data from the filename cell that the user has selected
          FileNameCell := DBGrid.DataSource.DataSet.Fields[1].Value;
          // Write filename to new row
          fs.Write(strTABLEDATAStart[1], 4);
          fs.Write(FileNameCell[1], Length(FileNameCell));
          fs.Write(strTABLEDataEnd[1], 5);

          // Get the data from the filepath cell that the user has selected
          FilePathCell := DBGrid.DataSource.DataSet.Fields[2].Value;
          // Write filepath to new row
          fs.Write(strTABLEDATAStart[1], 4);
          fs.Write(FilePathCell[1], Length(FilePathCell));
          fs.Write(strTABLEDATAEnd[1], 5);

          // Get the data from the filehash cell that the user has selected
          FileHashCell := DBGrid.DataSource.DataSet.Fields[3].Value;
          // Write hash to new row
          fs.Write(strTABLEDATAStart[1], 4) ;
          fs.Write(FileHashCell[1], Length(Trim(FileHashCell)));
          fs.Write(strTABLEDATAEnd[1], 5);
          // End the row
          fs.Write(strTABLEROWEnd[1], 5);
          fs.Write(#13#10, 2);
          DBGrid.DataSource.DataSet.Next;
        end;
        fs.Write(strTABLEFooter, 8);
        fs.Write(#13#10, 2);
        fs.writeansistring(IntToStr(NoOfRowsInGrid) + ' grid entries saved.');
        fs.Write(strBODYFooter, 7);
        fs.Write(#13#10, 2);
        fs.Write(strHTMLFooter, 7);
        fs.Write(#13#10, 2);
        DBGrid.DataSource.DataSet.EnableControls;
      finally
        fs.free;
        MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
        Application.ProcessMessages;
      end;
    end
  else
    if DBGrid.Name = 'frmDisplayGrid1' then
    begin
      // Same as above but use the 5 columns from COPY grid instead of the 3 of FILES
    end;
end;

// Deletes a DB table from the SQLite DB
procedure TfrmSQLiteDBases.EmptyDBTable(TableName : string; DBGrid : TDBGrid);
var
  DynamicSQLQuery: TSQLQuery;
begin
  DynamicSQLQuery := TSQLQuery.Create(nil);
  try
    try
      DynamicSQLQuery.DataBase := sqlFILES.Database;
      DynamicSQLQuery.Transaction := sqlFILES.Transaction;
      DynamicSQLQuery.SQL.Text := 'DELETE FROM ' + TableName;
      if SQLite3Connection1.Connected then
      begin
        SQLTransaction1.Active := True;
        DynamicSQLQuery.ExecSQL;
        SQLTransaction1.CommitRetaining; // Retain transaction is important here
      end;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
  finally
    DynamicSQLQuery.Free;
  end;
end;

// Deletes a DB table from the COPY DB
procedure TfrmSQLiteDBases.EmptyDBTableCOPY(TableName : string; DBGrid : TDBGrid);
var
  DynamicSQLQuery: TSQLQuery;
begin
  DynamicSQLQuery := TSQLQuery.Create(nil);
  try
    try
      DynamicSQLQuery.DataBase := sqlCOPY.Database;
      DynamicSQLQuery.Transaction := sqlCOPY.Transaction;
      DynamicSQLQuery.SQL.Text := 'DELETE FROM ' + TableName;
      if SQLite3Connection1.Connected then
      begin
        SQLTransaction1.Active := True;
        DynamicSQLQuery.ExecSQL;
        SQLTransaction1.CommitRetaining; // Retain transaction is important here
      end;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
  finally
    DynamicSQLQuery.Free;
  end;
end;

// Empties table of Compare Two Folders
procedure TfrmSQLiteDBases.EmptyDBTableC2F(TableName : string; DBGrid : TDBGrid);
var
  DynamicSQLQuery: TSQLQuery;
begin
  DynamicSQLQuery := TSQLQuery.Create(nil);
  try
    try
      DynamicSQLQuery.DataBase := sqlCOMPARETWOFOLDERS.Database;
      DynamicSQLQuery.Transaction := sqlCOMPARETWOFOLDERS.Transaction;
      DynamicSQLQuery.SQL.Text := 'DELETE FROM ' + TableName;
      if SQLite3Connection1.Connected then
      begin
        SQLTransaction1.Active := True;
        DynamicSQLQuery.ExecSQL;
        SQLTransaction1.CommitRetaining; // Retain transaction is important here
      end;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
  finally
    DynamicSQLQuery.Free;
  end;
end;

// SaveDBToCSV exports the DBGrid (DBGridName) to a CSV file (filename) for the user
// Based on example in FPC\3.0.2\source\packages\fcl-db\tests\testdbexport.pas
// Requires the lazdbexport package be installed in Lazarus IDE
procedure TfrmSQLiteDBases.SaveDBToCSV(DBGrid : TDBGrid; Filename : string);
var
  linetowrite : ansistring;
  n : integer;
  CSVFileToWrite : TFilestreamUTF8;
  KnownHashFlagIsSet : boolean;
begin
  Mainform.StatusBar2.SimpleText := 'Writing hash values to file...please wait';
  Application.ProcessMessages;
  linetowrite := '';
  n := 0;
  KnownHashFlagIsSet := false;

  try
    // Create a filestream for the output CSV. Add a header row first.
    CSVFileToWrite := TFileStreamUTF8.Create(Filename, fmCreate);
    linetowrite := 'Source Filename, Source Hash, Destination Filename, Destination Hash' + #13#10;
    n := Length(linetowrite);
    CSVFileToWrite.Write(linetowrite[1], n);

    // Now add all the hash strings to the CSV file stream
    DBGrid.DataSource.DataSet.First;

    // Write all columns, but dont try to include the Known Hash result if not computed to start with
    // This boolean check should be quicker instead of checking for every row whether the field is empty or not
    if MainForm.cbLoadHashList.checked then KnownHashFlagIsSet := true
      else KnownHashFlagIsSet := false;

    DBGrid.DataSource.Dataset.DisableControls;
    try
      DBGrid.DataSource.Dataset.First;
      while not DBGrid.DataSource.Dataset.EoF do
      begin
        if KnownHashFlagIsSet then
        begin
          // Include all columns, inc hash flag, but exclude the row count (not needed for a CSV output).
          linetowrite := (DBGrid.DataSource.DataSet.Fields[1].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[2].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[3].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[4].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[5].Text) + #13#10;
        end
        else
          begin
          // Include all columns, exc hash flag, but exclude the row count (not needed for a CSV output).
          linetowrite := (DBGrid.DataSource.DataSet.Fields[1].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[2].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[3].Text) + ',' +
                         (DBGrid.DataSource.DataSet.Fields[4].Text) + #13#10;
          end;
        n := 0;
        n := Length(linetowrite);
        CSVFileToWrite.Write(linetowrite[1], n);
        DBGrid.DataSource.Dataset.Next;
      end;
    finally
      DBGrid.DataSource.Dataset.EnableControls;
    end;
  finally
    CSVFileToWrite.Free;
  end;
  Mainform.StatusBar2.SimpleText := 'DONE';
  ShowMessage('Grid data now in ' + Filename);
end;

procedure TfrmSQLiteDBases.SaveC2FDBToCSV(DBGrid : TDBGrid; Filename : string);
var
  linetowrite : ansistring;
  n : integer;
  CSVFileToWrite : TFilestreamUTF8;

begin
  Mainform.StatusBar2.SimpleText := 'Writing results to file...please wait';
  Application.ProcessMessages;
  linetowrite := '';
  n := 0;

  try
    CSVFileToWrite := TFileStreamUTF8.Create(Filename, fmCreate);
    linetowrite := 'FolderA Filename, FolderA File Hash, FolderB Filename, FolderB File Hash' + #13#10;
    n := Length(linetowrite);
    CSVFileToWrite.Write(linetowrite[1], n);

    DBGrid.DataSource.Dataset.DisableControls;
    try
      DBGrid.DataSource.Dataset.First;
      while not DBGrid.DataSource.Dataset.EoF do
      begin
        linetowrite := (DBGrid.DataSource.DataSet.Fields[1].Text) + ',' +
                       (DBGrid.DataSource.DataSet.Fields[2].Text) + ',' +
                       (DBGrid.DataSource.DataSet.Fields[3].Text) + ',' +
                       (DBGrid.DataSource.DataSet.Fields[4].Text) + #13#10;

        n := 0;
        n := Length(linetowrite);
        CSVFileToWrite.Write(linetowrite[1], n);
        DBGrid.DataSource.Dataset.Next;
      end;
    finally
      DBGrid.DataSource.Dataset.EnableControls;
    end;
  finally
    CSVFileToWrite.Free;
  end;
  Mainform.StatusBar2.SimpleText := 'DONE';
  ShowMessage('Grid data now in ' + Filename);
end;

// Copies a DBGrid content to a temp text file then reads it into clipboard
procedure TfrmSQLiteDBases.DatasetToClipBoard(DBGrid : TDBGrid);
var
  DeletedOK : boolean;
  vStringList : TStringList;
  Exporter : TCSVExporter;
  ExportSettings: TCSVFormatSettings;
  FileName : string;
begin
    Filename := GetTempDir + 'QH_TmpFile.tmp';
    DeletedOK := false;
    // Go to start of grid
    DBGrid.DataSource.DataSet.First;
    // and export it...
    try
      Exporter := TCSVExporter.Create(nil);
      try
        ExportSettings := TCSVFormatSettings.Create(true);
        Exporter.FormatSettings := ExportSettings;
        Exporter.Dataset := DBGrid.DataSource.DataSet;
        Exporter.FileName := FileName;
        // if the temp outfile is written successfully with DBGrid content, load it to clipboard
        if Exporter.Execute > 0 then
          try
            // we can free it now the file is written OK. If we dont free now, we
            // cant use LoadFromFile next
            if assigned(exporter) then freeandnil(exporter);
            // Now load the text file into clipboard
            vStringList := TStringList.Create;
            vStringList.LoadFromFile(filename);
            // Write file to clipboard
            Clipboard.AsText := vStringList.Text;
          finally
            DeletedOK := DeleteFile(Filename);
            if DeletedOK = false then Showmessage('Could not delete temporary file ' + filename);
            if assigned(vStringList) then freeandnil(vStringList);
            ShowMessage('Grid content now in clipboard.');
          end;
      finally
        ExportSettings.Free;
      end;
    finally
      Exporter.Free;
    end;
end;

// ShowDuplicates lists entries with duplicate hash values from the FILES tab,
// by searching hash column for matches and then displays all rows fully
// for which duplicate hashes were found
procedure TfrmSQLiteDBases.ShowDuplicates(DBGrid : TDBGrid);
// Sourced from https://stackoverflow.com/questions/46345862/sql-how-to-return-all-column-fields-for-one-column-containing-duplicates
begin
  try
  DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
  TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize ' +
                        'FROM TBL_FILES WHERE HashValue IN ' +
                        '(SELECT HashValue FROM TBL_FILES ' +
                        'GROUP BY HashValue HAVING COUNT(*) > 1) ORDER BY hashvalue';
  SQLite3Connection1.Connected := True;
  SQLTransaction1.Active := True;
  MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
  DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// DeleteDuplicates remove duplicate files as found in the 'FILES' tab
procedure TfrmSQLiteDBases.DeleteDuplicates(DBGrid : TDBGrid);
var
  FileName, FilePath, NameAndPath, FileHash : string;
  i, FileDeletedCount : integer;
  FilesDeletedOK : boolean;
  slDuplicates, slDuplicatesDeleted : TStringList;
begin
  FilesDeletedOK := false;
  FileDeletedCount := 0;
  try
  slDuplicates := TStringList.Create;
  slDuplicates.Sorted := true;

  slDuplicatesDeleted := TStringList.Create;
  slDuplicatesDeleted.Sorted := true;
  DBGrid.DataSource.DataSet.DisableControls;
  DBGrid.DataSource.Dataset.First;
  while not DBGrid.DataSource.DataSet.EOF do
    begin
      for i := 0 to DBGrid.DataSource.DataSet.FieldCount -1 do
      begin
        FileName := DBGrid.DataSource.DataSet.Fields[1].Value;
        FilePath := DBGrid.DataSource.DataSet.Fields[2].Value;
        FileHash := DBGrid.DataSource.DataSet.Fields[3].Value;
        NameAndPath := FilePath+FileName;
        // Now, add the hash value, but only if it's not already in the stringlist
        // If the currently examined hashvalue IS in the list, then it must be a duplicate
        // and can therefore be deleted
        if slDuplicates.IndexOf(FileHash) > -1 then
          begin
            FilesDeletedOK := DeleteFile(NameAndPath); // it's a duplicate
            if FilesDeletedOK = true then
            begin
              inc(FileDeletedCount, 1);
              slDuplicatesDeleted.Add(NameAndPath + ',' + FileHash + ', was deleted OK');
            end;
            // reset deletion flag
            FilesDeletedOK := false;
          end
          else slDuplicates.add(FileHash);
        // Go to next record
        DBGrid.DataSource.DataSet.Next;
      end;
    end;
    DBGrid.DataSource.DataSet.EnableControls;

    // Allow user the choice to save results of the duplicate file deletions
    try
      if MessageDlg(IntToStr(FileDeletedCount) + ' duplicate files deleted. Save details to text file?', mtConfirmation,
        [mbCancel, mbNo, mbYes],0) = mrYes then
        begin
          MainForm.FilesDBGrid_SaveCSVDialog.Title := 'Save deleted file record as...';
          MainForm.FilesDBGrid_SaveCSVDialog.InitialDir := GetCurrentDir;
          MainForm.FilesDBGrid_SaveCSVDialog.Filter := 'Comma Sep|*.csv';
          MainForm.FilesDBGrid_SaveCSVDialog.DefaultExt := 'csv';
          if MainForm.FilesDBGrid_SaveCSVDialog.Execute then
            begin
               slDuplicatesDeleted.SaveToFile(MainForm.FilesDBGrid_SaveCSVDialog.Filename);
            end;
        end;
    except
      // do nothing
    end;
  finally
    slDuplicates.free;
  end;
end;


// *** Start of FILES tab related database routines ***

// Write computed values from the FILES tab to the database table TBL_FILES
procedure TfrmSQLiteDBases.WriteFILESValuesToDatabase(Filename, Filepath, HashValue, FileSize : string; KnownHash : boolean);
var
  KnownHashFlag : string;
begin
  try
    sqlFILES.Close;
    // Insert the values into the database. We're using ParamByName which prevents SQL Injection
    // http://wiki.freepascal.org/Working_With_TSQLQuery#Parameters_in_TSQLQuery.SQL

    if MainForm.cbLoadHashList.Checked then
      begin
        if KnownHash = false then
          begin
            KnownHashFlag := 'No';
            sqlFILES.SQL.Text := 'INSERT into TBL_FILES (Filename, FilePath, HashValue, FileSize, KnownHashFlag) values (:Filename,:FilePath,:HashValue,:FileSize,:KnownHashFlag)';
          end
        else
        begin
          KnownHashFlag := 'Yes';
          sqlFILES.SQL.Text := 'INSERT into TBL_FILES (Filename, FilePath, HashValue, FileSize, KnownHashFlag) values (:Filename,:FilePath,:HashValue,:FileSize,:KnownHashFlag)';
        end;
      end
    else sqlFILES.SQL.Text := 'INSERT into TBL_FILES (Filename, FilePath, HashValue, FileSize) values (:Filename,:FilePath,:HashValue,:FileSize)';

    SQLTransaction1.Active := True;
    sqlFILES.Params.ParamByName('Filename').AsString := Filename;
    sqlFILES.Params.ParamByName('FilePath').AsString := FilePath;
    sqlFILES.Params.ParamByName('HashValue').AsString := hashvalue;
    sqlFILES.Params.ParamByName('FileSize').AsString := FileSize;
    if MainForm.cbLoadHashList.Checked then
      begin
        sqlFILES.Params.ParamByName('KnownHashFlag').AsString := KnownHashFlag;
      end;
    sqlFILES.ExecSQL;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab to sort entries by ID in order
procedure TfrmSQLiteDBases.SortByID(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                          'FROM TBL_FILES ORDER BY Id';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
end;

// Used by the FILES tab to sort entries by filename alphabetically
procedure TfrmSQLiteDBases.SortByFileName(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                          'FROM TBL_FILES ORDER BY FileName';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
end;


// Used by FILES tab for sorting entries by file path alphabetically
procedure TfrmSQLiteDBases.SortByFilePath(DBGrid : TDBGrid);
begin
 try
   DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
   TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                        'FROM TBL_FILES ORDER BY FilePath';
   SQLite3Connection1.Connected := True;
   SQLTransaction1.Active := True;
   MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
   DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;


// Used by the FILES tab display grid to sort by hash
procedure TfrmSQLiteDBases.SortByHash(DBGrid : TDBGrid);
begin
 try
   DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
   TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                        'FROM TBL_FILES ORDER BY HashValue';
   SQLite3Connection1.Connected := True;
   SQLTransaction1.Active := True;
   MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
   DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab display grid to sort by the Yes\No values of Known Hash import
procedure TfrmSQLiteDBases.SortByHashList(DBGrid : TDBGrid);
begin
 try
   DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
   TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                        'FROM TBL_FILES ORDER BY KnownHashFlag';
   SQLite3Connection1.Connected := True;
   SQLTransaction1.Active := True;
   MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
   DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab display grid to filter out values unknown to imported hash list
// i.e. Filter out all the rows that are No in Known to hash import
procedure TfrmSQLiteDBases.FilterOutHashListNO(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close;
    // This SQL query may not scale to large data sets as it uses the LIKE word
    // But it should be OK for many thousands of rows, but perhas not millions.
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text :=  'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                                                      'FROM TBL_FILES WHERE KnownHashFlag LIKE ''No''';

    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab display grid to filter out values known to imported hash list
// i.e. Filter out all the rows that are Yes in Known to hash import
procedure TfrmSQLiteDBases.FilterOutHashListYES(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close;
    // This SQL query may not scale to large data sets as it uses the LIKE word
    // But it should be OK for many thousands of rows, but perhas not millions.
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text :=  'SELECT Id, Filename, FilePath, HashValue, FileSize, KnownHashFlag ' +
                                                      'FROM TBL_FILES WHERE KnownHashFlag LIKE ''Yes''';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
  except
  on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab display grid to list all again
procedure TfrmSQLiteDBases.ShowAll(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT * FROM TBL_FILES';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the FILES tab display grid to copy the content of Column 1 (filename) to clipboard
procedure TfrmSQLiteDBases.CopyFilenameOfSelectedCell(DBGrid : TDBGrid);
var
  CellOfInterest : string;
begin
  CellOfInterest := '';
  if not (DBGrid.DataSource.DataSet.Fields[1].Value = NULL) then
  begin
    CellOfInterest := DBGrid.DataSource.DataSet.Fields[1].Value;
    Clipboard.AsText := CellOfInterest;
  end;
end;

// // Used by the FILES tab display grid to copy the content of Column 2 (file path) to clipboard
procedure TfrmSQLiteDBases.CopyFilePathOfSelectedCell(DBGrid : TDBGrid);
var
  CellOfInterest : string;
begin
  CellOfInterest := '';
  if not (DBGrid.DataSource.DataSet.Fields[2].Value = NULL) then
  begin
    CellOfInterest := DBGrid.DataSource.DataSet.Fields[2].Value;
    Clipboard.AsText := CellOfInterest;
  end;
end;

// Used by the FILES tab display grid to copy the content of Column 3 (Hash Value) to clipboard
procedure TfrmSQLiteDBases.CopyHashOfSelectedCell(DBGrid : TDBGrid);
var
  CellOfInterest : string;
begin
  CellOfInterest := '';
  if not (DBGrid.DataSource.DataSet.Fields[3].Value = NULL) then
  begin
    CellOfInterest := DBGrid.DataSource.DataSet.Fields[3].Value;
    Clipboard.AsText := CellOfInterest;
  end;
end;

// Used by the FILES tab display grid to copy all the hash values of Column 3 to clipboard
// Useful to create hashlists without adding the entire grid content
procedure TfrmSQLiteDBases.CopyAllHashesFILESTAB(DBGrid : TDBGrid; UseFileFlag : Boolean);
var
  slFileHashes   : TStringList;
  tempfile       : TFileStream;
  n : integer;
  ChosenHashAlg,
    Header,
    FileForCopiedHashes,
    linetowrite  : string;
begin
  ChosenHashAlg := '';
  Header        := '';
  n             := 0;
  case MainForm.AlgorithmChoiceRadioBox3.ItemIndex of
      0: begin
      ChosenHashAlg := 'MD5';
      end;
      1: begin
      ChosenHashAlg := 'SHA-1';
      end;
      2: begin
      ChosenHashAlg := 'SHA-3';
      end;
      3: begin
      ChosenHashAlg := 'SHA256';
      end;
      4: begin
      ChosenHashAlg := 'SHA512';
      end;
      5: begin
      ChosenHashAlg := 'xxHash';
      end;
      6: begin
      ChosenHashAlg := 'Blake2B';
      end;
  end;

  Header := ChosenHashAlg;

  // If hash value count too large for clipboard use, write to a file
  if UseFileFlag then
  begin
    if MainForm.SaveDialog8_SaveJustHashes.Execute then
    begin
      Mainform.StatusBar2.SimpleText := 'Writing hash values to file...please wait';
      Application.ProcessMessages;
      FileForCopiedHashes := MainForm.SaveDialog8_SaveJustHashes.FileName;

      try
        tempfile := TFileStream.Create(FileForCopiedHashes, fmCreate);
        // Give the list a header of the chosen hash algorithm
        linetowrite := Header + #13#10;
        tempfile.Write(linetowrite[1], Length(linetowrite));
        // Now add all the hash strings
        DBGrid.DataSource.DataSet.DisableControls;
        DBGrid.DataSource.DataSet.First;
        while not DBGrid.DataSource.DataSet.EOF do
        begin
          linetowrite := (DBGrid.DataSource.DataSet.Fields[3].Text) + #13#10;
          n := Length(linetowrite);
          try
            tempfile.Write(linetowrite[1], n);
          finally
            DBGrid.DataSource.DataSet.Next;
          end;
        end;
        DBGrid.DataSource.DataSet.EnableControls;
      finally
        tempfile.Free;
      end;
      Mainform.StatusBar2.SimpleText := 'DONE';
      ShowMessage('Hash column content now in ' + FileForCopiedHashes);
    end
    else ShowMessage('Unable to create a file to store the hashes. Check write permissions of location');
  end
  else // Hash value count should go into clipboard OK unless the host is shockingly low on memory
  begin
    Mainform.StatusBar2.SimpleText := 'Writing hash values to clipboard...please wait';
    try
      slFileHashes := TStringList.Create;
      slFileHashes.Add(Header); // Give the list a header of the chosen hash algorithm
      DBGrid.DataSource.DataSet.DisableControls;
      DBGrid.DataSource.DataSet.First;
      while not DBGrid.DataSource.DataSet.EOF do
      begin
        slFileHashes.Add(DBGrid.DataSource.DataSet.Fields[3].Text);
        DBGrid.DataSource.DataSet.Next;
      end;
      DBGrid.DataSource.DataSet.EnableControls;
      Clipboard.AsText := slFileHashes.Text;
    finally
      slFileHashes.Free;
      Mainform.StatusBar2.SimpleText := 'DONE. Hash column content now in clipboard.';
      ShowMessage('Hash column content now in clipboard.');
    end;
  end;
end;

// *** Start of COMPARE TWO FOLDERS tab related functions ***

// Populate the database table with empty rows first, to then be populated using UPDATE
procedure TfrmSQLiteDBases.Write_INSERT_All_Rows_Required(RowCount : integer);
var
  i : integer;
begin
  for i:= 0 to RowCount -1 do
    begin
      try
        sqlCOMPARETWOFOLDERS.Close;
        sqlCOMPARETWOFOLDERS.SQL.Text := 'INSERT into TBL_COMPARE_TWO_FOLDERS (FolderAndFileNameA, FolderAndFileNameAHash, FolderAndFileNameB, FolderAndFileNameBHash) values (:FolderAFilename,:FolderAFileHash,:FolderBFilename,:FolderBFileHash)';
        SQLTransaction1.Active := True;
        sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderAFilename').AsString := '';
        sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderAFileHash').AsString := '';
        sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderBFilename').AsString := '';
        sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderBFileHash').AsString := '';
        sqlCOMPARETWOFOLDERS.ExecSQL;
      except
          on E: EDatabaseError do
          begin
            MessageDlg('Error','Unable to create all rows required for comparison. Technical error message: ' + E.Message,mtError,[mbOK],0);
          end;
      end;
    end;
end;

procedure TfrmSQLiteDBases.Write_COMPARE_TWO_FOLDERS_FolderA(Col1, Col2 : string; Counter : integer);
{ Col1 : Filename from Folder A
  Col2 : Hashvalue from FileA in FolderA
}
begin
  try
    sqlCOMPARETWOFOLDERS.Close;       // UPDATE only works if rows already exist. If count is different need to work out how to insert into Cols 3 and 4
    sqlCOMPARETWOFOLDERS.SQL.Text := 'UPDATE TBL_COMPARE_TWO_FOLDERS SET FolderAndFileNameA =:FolderAFilename, FolderAndFileNameAHash =:FolderAFileHash WHERE Id=:Counter';
    SQLTransaction1.Active := True;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderAFilename').AsString := Col1;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderAFileHash').AsString := Col2;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('Counter').AsString := IntToStr(Counter);
    sqlCOMPARETWOFOLDERS.ExecSQL;

  except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
  end;
end;

procedure TfrmSQLiteDBases.Write_COMPARE_TWO_FOLDERS_FolderB(Col3, Col4 : string; Counter : integer);
{ Col3 : Filename from Folder B
  Col4 : Hashvalue from FileB in FolderB
}
begin
  try
    sqlCOMPARETWOFOLDERS.Close;       // UPDATE only works if rows already exist. If count is different need to work out how to insert into Cols 3 and 4
    sqlCOMPARETWOFOLDERS.SQL.Text := 'UPDATE TBL_COMPARE_TWO_FOLDERS SET FolderAndFileNameB =:FolderBFilename, FolderAndFileNameBHash =:FolderBFileHash WHERE Id=:Counter';
    SQLTransaction1.Active := True;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderBFilename').AsString := Col3;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('FolderBFileHash').AsString := Col4;
    sqlCOMPARETWOFOLDERS.Params.ParamByName('Counter').AsString         := IntToStr(Counter);
    sqlCOMPARETWOFOLDERS.ExecSQL;

  except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
  end;
end;

// Used by the COMPARE TWO FOLDERS grid to display mis-matched files and hashes to the user via right click option
// New to v3.3.0
procedure TfrmSQLiteDBases.ShowMismatchesC2F(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT ID, FolderAndFileNameA, FolderAndFileNameAHash, FolderAndFileNameB, FolderAndFileNameBHash ' +
                          'FROM TBL_COMPARE_TWO_FOLDERS WHERE FolderAndFileNameAHash <> FolderAndFileNameBHash';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    frmDisplayGrid3.dbGridC2F.Options := frmDisplayGrid3.dbGridC2F.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
end;

// Used by the COMPARE TWO FOLDERS grid to show all items
procedure TfrmSQLiteDBases.ShowAllC2FGRID(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlCOMPARETWOFOLDERS but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT * FROM TBL_COMPARE_TWO_FOLDERS';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    frmDisplayGrid3.dbGridC2F.Options := frmDisplayGrid3.dbGridC2F.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// *** Start of COPY tab related functions ***

// Write computed values from the COPY tab to the database table TBL_COPY
procedure TfrmSQLiteDBases.WriteCOPYValuesToDatabase(Col1, Col2, Col3, Col4, Col5 : string);
{Col1 : Source Filename
 Col2 : Source Hash
 Col3 : Destination Filename
 Col4 : Destination Hash
 Col5 : DateAttributes;}
begin
  try
    // Insert the values into the database. We're using ParamByName which prevents SQL Injection
    // http://wiki.freepascal.org/Working_With_TSQLQuery#Parameters_in_TSQLQuery.SQL
    sqlCOPY.Close;
    sqlCOPY.SQL.Text := 'INSERT into TBL_COPY (SourceFilename, SourceHash, DestinationFilename, DestinationHash, DateAttributes) values (:SourceFilename,:SourceHash,:DestinationFilename,:DestinationHash,:DateAttributes)';
    SQLTransaction1.Active := True;
    sqlCOPY.Params.ParamByName('SourceFilename').AsString      := Col1;
    sqlCOPY.Params.ParamByName('SourceHash').AsString          := Col2;
    sqlCOPY.Params.ParamByName('DestinationFilename').AsString := Col3;
    sqlCOPY.Params.ParamByName('DestinationHash').AsString     := Col4;
    sqlCOPY.Params.ParamByName('DateAttributes').AsString      := Col5;
    sqlCOPY.ExecSQL;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the COPY tab display grid, to sort by source filename...Col 1
procedure TfrmSQLiteDBases.SortBySourceFilename(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, SourceFilename, SourceHash, DestinationFilename, DestinationHash, DateAttributes ' +
                          'FROM TBL_COPY ORDER BY SourceFilename';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
end;

// Used by the COPY tab display grid to sort by destination filename...Col 3
procedure TfrmSQLiteDBases.SortByDestinationFilename(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, SourceFilename, SourceHash, DestinationFilename, DestinationHash, DateAttributes ' +
                        'FROM TBL_COPY ORDER BY DestinationFilename';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
    except
      on E: EDatabaseError do
      begin
        MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
      end;
    end;
end;

// Used by the COPY tab display grid to sort by source hash, Col 2
procedure TfrmSQLiteDBases.SortBySourceHash(DBGrid : TDBGrid);
begin
 try
   DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
   TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, SourceFilename, SourceHash, DestinationFilename, DestinationHash, DateAttributes ' +
                          'FROM TBL_COPY ORDER BY SourceHash';
   SQLite3Connection1.Connected := True;
   SQLTransaction1.Active := True;
   frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
   DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the COPY tab display grid to sort by destination hash...Col 4
procedure TfrmSQLiteDBases.SortByDestinationHash(DBGrid : TDBGrid);
begin
 try
   DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlFILES but the query connected to the grid
   TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT Id, SourceFilename, SourceHash, DestinationFilename, DestinationHash, DateAttributes ' +
                          'FROM TBL_COPY ORDER BY DestinationHash';
   SQLite3Connection1.Connected := True;
   SQLTransaction1.Active := True;
   frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
   DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Used by the COPY grid to show all items
procedure TfrmSQLiteDBases.ShowAllCOPYGRID(DBGrid : TDBGrid);
begin
  try
    DBGrid.DataSource.Dataset.Close; // <--- we don't use sqlCOPY but the query connected to the grid
    TSQLQuery(DBGrid.DataSource.Dataset).SQL.Text := 'SELECT * FROM TBL_COPY';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
    DBGrid.DataSource.Dataset.Open;
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// Saves the grid in COPY window to HTML. If small volume of records, uses a stringlist.
// If big volume, uses file stream.
procedure TfrmSQLiteDBases.SaveCOPYWindowToHTML(DBGrid : TDBGrid; Filename : string);
var
   strTitle, strTableHeader, SourceFilename, DestinationFileName, DateAttributes,
     SourceFileHash, DestinationFileHash : string;
  NoOfRowsInGrid    : integer;
  sl                : TStringList;
  fs                : TFileStreamUTF8;

  const
    strHTMLHeader      = '<HTML>'  ;
    strTITLEHeader     = '<TITLE>QuickHash HTML Output' ;
    strBODYHeader      = '<BODY>'  ;
    strTABLEROWStart   = '<TR>'    ;
    strTABLEDATAStart  = '<TD>'    ;
    strSrcFilenameHead = '<td>Source Filename</td>';
    strSrcHashHead     = '<td>Source Hash</td>';
    strDestFilenameHead= '<td>Destination Filename</td>';
    strDestHashHead    = '<td>Destination Hash</td>';
    strDateAttr        = '<td>Original Date Attributes</td>';
    strTABLEDataEnd    = '</TD>'   ;
    strTABLEROWEnd     = '</TR>'   ;
    strTABLEFooter     = '</TABLE>';
    strBODYFooter      = '</BODY>' ;
    strTITLEFooter     = '</TITLE>';
    strHTMLFooter      = '</HTML>' ;

begin
  NoOfRowsInGrid := 0;
  // If database volume not too big, use memory and stringlists. Otherwise, use file writes
  NoOfRowsInGrid := CountGridRows(DBGrid);// Count the rows first. If not too many, use memory. Otherwise, use filestreams
  if (NoOfRowsInGrid < 10000) and (NoOfRowsInGrid > -1) then
  try
    MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
    Application.ProcessMessages;
    // Write the grid to a stringlist
    sl := TStringList.Create;
    sl.add('<HTML>');
    sl.add('<TITLE>QuickHash HTML Output</TITLE>');
    sl.add('<BODY>');
    sl.add('<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>');
    sl.add('<table border=1>');
    sl.add('<tr><td>Source Filename</td><td>Source Hash</td><td>Destination Filename</td><td>Destination Hash</td><td>Original Date Attributes</td></tr>');

    DBGrid.DataSource.DataSet.DisableControls;
    DBGrid.DataSource.DataSet.First;
    while not DBGrid.DataSource.DataSet.EOF do
      begin
          sl.add('<tr>');
          // Get the data from the source filename cell
          SourceFilename := DBGrid.DataSource.DataSet.Fields[1].Value;
          sl.add('<td>'+SourceFilename+'</td>');
          // Get the data from the source file hash cell
          SourceFileHash := DBGrid.DataSource.DataSet.Fields[2].Value;
          sl.add('<td>'+SourceFileHash+'</td>');
          // Get the data from the destination name
          DestinationFilename := DBGrid.DataSource.DataSet.Fields[3].Value;
          sl.add('<td>'+DestinationFilename+'</td>');
          // Get the data from the source file hash cell
          DestinationFileHash := DBGrid.DataSource.DataSet.Fields[4].Value;
          sl.add('<td>'+DestinationFileHash+'</td>');
          // Get the data from the source file hash cell
          DateAttributes := DBGrid.DataSource.DataSet.Fields[5].Value;
          sl.add('<td>'+DateAttributes+'</td>');
          sl.add('</tr>');
          DBGrid.DataSource.DataSet.Next;
        end;
    sl.add('</TABLE>');
    sl.add('</BODY> ');
    sl.add('</HTML> ');
    DBGrid.DataSource.DataSet.EnableControls;
    sl.SaveToFile(Filename);
  finally
    sl.free;
    MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
    Application.ProcessMessages;
  end
  else // Use filestream method because there's more than 10K rows. Too many to add HTML tags and store in memory
    try
    if not FileExists(filename) then
      begin
        fs := TFileStreamUTF8.Create(Filename, fmCreate);
      end
    else fs := TFileStreamUTF8.Create(Filename, fmOpenReadWrite);

    // Create HTML Header Data
    MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
    strTitle := '<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>';
    Application.ProcessMessages;

    fs.Write(strHTMLHeader[1], Length(strHTMLHeader));
    fs.Write(#13#10, 2);
    fs.Write(strTITLEHeader[1], Length(strTITLEHeader));
    fs.Write(strTITLEFooter[1], Length(strTITLEFooter));
    fs.Write(#13#10, 2);
    fs.Write(strBODYHeader[1], Length(strBODYHeader));
    fs.Write(strTitle[1], Length(strTitle));
    fs.Write(#13#10, 2);
    fs.Write('<table border=1>', 16);

    // Add a header row to the HTML
    strTableHeader := '<tr>'+ strSrcFilenameHead + strSrcHashHead + strDestFilenameHead + strDestHashHead + strDateAttr + '</tr>';
    fs.Write(strTableHeader[1], Length(strTableHeader));

    // Now write the main table content, row by row

    { strTABLEROWStart   = '<TR>'      = 4 bytes
      strTABLEDATAStart  = '<TD>'      = 4 bytes
      strTABLEDataEnd    = '</TD>'     = 5 bytes
      strTABLEROWEnd     = '</TR>'     = 5 bytes
      strTABLEFooter     = '</TABLE>'  = 8 bytes
      strBODYFooter      = '</BODY>'   = 7 bytes
      strTITLEFooter     = '</TITLE>'  = 8 bytes
      strHTMLFooter      = '</HTML>'   = 7 bytes}
      DBGrid.DataSource.DataSet.DisableControls;
      DBGrid.DataSource.DataSet.First;
    while not DBGrid.DataSource.DataSet.EOF do
      begin
        // Start new row
        fs.Write(strTABLEROWStart[1], 4);
          // Get the source filename cell
          SourceFilename := DBGrid.DataSource.DataSet.Fields[1].Value;
          // Write source filename to new row
          fs.Write(strTABLEDATAStart[1], 4);
          fs.Write(SourceFilename[1], Length(SourceFilename));
          fs.Write(strTABLEDataEnd[1], 5);

          // Get the source hash value
          SourceFileHash := DBGrid.DataSource.DataSet.Fields[2].Value;
          // Write the source hash value
          fs.Write(strTABLEDATAStart[1], 4);
          fs.Write(SourceFileHash[1], Length(SourceFileHash));
          fs.Write(strTABLEDATAEnd[1], 5);

          // Get the destination filename
          DestinationFileName := DBGrid.DataSource.DataSet.Fields[3].Value;
          // Write the destination hash
          fs.Write(strTABLEDATAStart[1], 4) ;
          fs.Write(DestinationFileName[1], Length(Trim(DestinationFileName)));
          fs.Write(strTABLEDATAEnd[1], 5);

          // Get the destination hash
          DestinationFileHash := DBGrid.DataSource.DataSet.Fields[4].Value;
          // Write the destination hash
          fs.Write(strTABLEDATAStart[1], 4) ;
          fs.Write(DestinationFileHash[1], Length(Trim(DestinationFileHash)));
          fs.Write(strTABLEDATAEnd[1], 5);

          // Get the date attributes from the filesystem
          DateAttributes := DBGrid.DataSource.DataSet.Fields[5].Value;
          // Write the date attributes
          fs.Write(strTABLEDATAStart[1], 4) ;
          fs.Write(DateAttributes[1], Length(Trim(DateAttributes)));
          fs.Write(strTABLEDATAEnd[1], 5);

        // End the row
        fs.Write(strTABLEROWEnd[1], 5);
        fs.Write(#13#10, 2);
        DBGrid.DataSource.DataSet.Next;
      end;
    fs.Write(strTABLEFooter, 8);
    fs.Write(#13#10, 2);
    fs.writeansistring(IntToStr(NoOfRowsInGrid) + ' grid entries saved.');
    fs.Write(strBODYFooter, 7);
    fs.Write(#13#10, 2);
    fs.Write(strHTMLFooter, 7);
    fs.Write(#13#10, 2);
    finally
      DBGrid.DataSource.DataSet.EnableControls;
      fs.free;
      MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
      Showmessage('Data saved to HTML file ' + Filename);
      Application.ProcessMessages;
    end;
end;

// Saves the "Compare Two Folders" grid to HTML. If small volume of records, uses a stringlist.
// If big volume, uses file stream.
procedure TfrmSQLiteDBases.SaveC2FWindowToHTML(DBGrid : TDBGrid; Filename : string);
var
   strTitle, FolderAFilenameA, FolderAFilenameAHash, FolderBFilenameB, FolderBFilenameBHash : string;
  NoOfRowsInGrid    : integer;
  sl                : TStringList;
  fs                : TFileStreamUTF8;

  const
    strHTMLHeader      = '<HTML>'  ;
    strTITLEHeader     = '<TITLE>QuickHash HTML Output' ;
    strBODYHeader      = '<BODY>'  ;
    strTABLEROWStart   = '<TR>'    ;
    strTABLEDATAStart  = '<TD>'    ;
    strTABLEDataEnd    = '</TD>'   ;
    strTABLEROWEnd     = '</TR>'   ;
    strTABLEFooter     = '</TABLE>';
    strBODYFooter      = '</BODY>' ;
    strTITLEFooter     = '</TITLE>';
    strHTMLFooter      = '</HTML>' ;

begin
  NoOfRowsInGrid := 0;
  // If database volume not too big, use memory and stringlists. Otherwise, use file writes
  NoOfRowsInGrid := CountGridRows(DBGrid);// Count the rows first. If not too many, use memory. Otherwise, use filestreams
  if (NoOfRowsInGrid < 10000) and (NoOfRowsInGrid > -1) then
  try
    MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
    Application.ProcessMessages;
    // Write the grid to a stringlist
    sl := TStringList.Create;
    sl.add('<HTML>');
    sl.add('<TITLE>QuickHash HTML Output</TITLE>');
    sl.add('<BODY>');
    sl.add('<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>');
    sl.add('<table border=1>');
    DBGrid.DataSource.DataSet.DisableControls;
    DBGrid.DataSource.DataSet.First;
    while not DBGrid.DataSource.DataSet.EOF do
      begin
          sl.add('<tr>');
          FolderAFilenameA := DBGrid.DataSource.DataSet.Fields[1].Value;
          sl.add('<td>'+FolderAFilenameA+'</td>');
          FolderAFilenameAHash := DBGrid.DataSource.DataSet.Fields[2].Value;
          sl.add('<td>'+FolderAFilenameAHash+'</td>');
          FolderBFilenameB := DBGrid.DataSource.DataSet.Fields[3].Value;
          sl.add('<td>'+FolderBFilenameB+'</td>');
          FolderBFilenameBHash := DBGrid.DataSource.DataSet.Fields[4].Value;
          sl.add('<td>'+FolderBFilenameBHash+'</td>');
          sl.add('</tr>');
          DBGrid.DataSource.DataSet.Next;
        end;
    sl.add('</TABLE>');
    sl.add('</BODY> ');
    sl.add('</HTML> ');
    DBGrid.DataSource.DataSet.EnableControls;
    sl.SaveToFile(Filename);
  finally
    sl.free;
    MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
    Application.ProcessMessages;
  end
  else // Use filestream method because there's more than 10K rows. Too many to add HTML tags and store in memory
    try
    if not FileExists(filename) then
      begin
        fs := TFileStreamUTF8.Create(Filename, fmCreate);
      end
    else fs := TFileStreamUTF8.Create(Filename, fmOpenReadWrite);

    MainForm.StatusBar2.Caption:= ' Saving grid to ' + Filename + '...please wait';
    strTitle := '<p>HTML Output generated ' + FormatDateTime('YYYY/MM/DD HH:MM:SS', Now) + ' using ' + MainForm.Caption + '</p>';
    Application.ProcessMessages;

    fs.Write(strHTMLHeader[1], Length(strHTMLHeader));
    fs.Write(#13#10, 2);
    fs.Write(strTITLEHeader[1], Length(strTITLEHeader));
    fs.Write(strTITLEFooter[1], Length(strTITLEFooter));
    fs.Write(#13#10, 2);
    fs.Write(strBODYHeader[1], Length(strBODYHeader));
    fs.Write(strTitle[1], Length(strTitle));
    fs.Write(#13#10, 2);
    fs.Write('<table border=1>', 16);

    { strTABLEROWStart   = '<TR>'      = 4 bytes
      strTABLEDATAStart  = '<TD>'      = 4 bytes
      strTABLEDataEnd    = '</TD>'     = 5 bytes
      strTABLEROWEnd     = '</TR>'     = 5 bytes
      strTABLEFooter     = '</TABLE>'  = 8 bytes
      strBODYFooter      = '</BODY>'   = 7 bytes
      strTITLEFooter     = '</TITLE>'  = 8 bytes
      strHTMLFooter      = '</HTML>'   = 7 bytes}
      DBGrid.DataSource.DataSet.DisableControls;
      DBGrid.DataSource.DataSet.First;
    while not DBGrid.DataSource.DataSet.EOF do
      begin
        // Start new row
        fs.Write(strTABLEROWStart[1], 4);
        // Get the Folder A Filename A filename
        FolderAFilenameA := DBGrid.DataSource.DataSet.Fields[1].Value;
        // Write Folder A Filename A to row
        fs.Write(strTABLEDATAStart[1], 4);
        fs.Write(FolderAFilenameA[1], Length(FolderAFilenameA));
        fs.Write(strTABLEDataEnd[1], 5);

        // Get the Folder A Filename hash
        FolderAFilenameAHash := DBGrid.DataSource.DataSet.Fields[2].Value;
        // Write Folder A Filename hash to row
        fs.Write(strTABLEDATAStart[1], 4);
        fs.Write(FolderAFilenameAHash[1], Length(FolderAFilenameAHash));
        fs.Write(strTABLEDATAEnd[1], 5);

        // Get the Folder B Filename B filename
        FolderBFilenameB := DBGrid.DataSource.DataSet.Fields[3].Value;
        // Write the Filename B
        fs.Write(strTABLEDATAStart[1], 4) ;
        fs.Write(FolderBFilenameB[1], Length(Trim(FolderBFilenameB)));
        fs.Write(strTABLEDATAEnd[1], 5);

        // Get the Folder B Filename B hash
        FolderBFilenameBHash := DBGrid.DataSource.DataSet.Fields[4].Value;
        // Write the Folder B Filename B hash
        fs.Write(strTABLEDATAStart[1], 4) ;
        fs.Write(FolderBFilenameBHash[1], Length(Trim(FolderBFilenameBHash)));
        fs.Write(strTABLEDATAEnd[1], 5);

        // End the row
        fs.Write(strTABLEROWEnd[1], 5);
        fs.Write(#13#10, 2);
        DBGrid.DataSource.DataSet.Next;
      end;
    fs.Write(strTABLEFooter, 8);
    fs.Write(#13#10, 2);
    fs.writeansistring(IntToStr(NoOfRowsInGrid) + ' grid entries saved.');
    fs.Write(strBODYFooter, 7);
    fs.Write(#13#10, 2);
    fs.Write(strHTMLFooter, 7);
    fs.Write(#13#10, 2);
    finally
      DBGrid.DataSource.DataSet.EnableControls;
      fs.free;
      MainForm.StatusBar2.Caption:= ' Data saved to HTML file ' + Filename + '...OK';
      Showmessage('Data saved to HTML file ' + Filename);
      Application.ProcessMessages;
    end;
end;

// There is an UpdateGridXXX routine for each tab where a DBGrid is used.
// Each one is to populate the grid with the data from the query.

// FILES tab update grid routine
procedure TfrmSQLiteDBases.UpdateGridFILES(Sender: TObject);
  begin
    try
    sqlFILES.Close;
    sqlFILES.SQL.Text := 'SELECT * FROM TBL_FILES';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    sqlFILES.Open;
    MainForm.RecursiveDisplayGrid1.Options:= MainForm.RecursiveDisplayGrid1.Options + [dgAutoSizeColumns];
    except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// COPY tab update grid routine
procedure TfrmSQLiteDBases.UpdateGridCOPYTAB(Sender: TObject);
  begin
    try
    sqlCOPY.Close;
    sqlCOPY.SQL.Text := 'SELECT * FROM TBL_COPY';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    sqlCOPY.Open;
    frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options:= frmDisplayGrid1.RecursiveDisplayGrid_COPY.Options + [dgAutoSizeColumns];
    except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

// COMPARE TWO FOLDERS tab update grid routine
procedure TfrmSQLiteDBases.UpdateGridCOMPARETWOFOLDERSTAB(Sender: TObject);
  begin
    try
    sqlCOMPARETWOFOLDERS.Close;
    sqlCOMPARETWOFOLDERS.SQL.Text := 'SELECT * FROM TBL_COMPARE_TWO_FOLDERS';
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    sqlCOMPARETWOFOLDERS.Open;
    frmDisplayGrid3.dbGridC2F.Options := frmDisplayGrid3.dbGridC2F.Options + [dgAutoSizeColumns];
    except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;

procedure TfrmSQLiteDBases.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SQLite3Connection1.Close;
  SQLite3Connection1.Free;
end;

{  procedure frmSQLiteDBases.btnCountRowsClick(Sender: TObject);
  begin

    //SQLite3Connection1.Close; // Ensure the connection is closed when we start

    //SQLite3Connection1.Password := txtPass.Text; // The current password

    // Try to perform query
    try
      SQLite3Connection1.Connected := True;

      // Set SQL text to count all rows from the TBL_FILES table
      sqlFILES.SQL.Clear;
      sqlFILES.SQL.Text := 'Select Count(*) from TBL_FILES';
      sqlFILES.Open;

      // Allow the DBGrid to view the results of our query
      DataSource1.DataSet := sqlFILES;
      DBGrid1.DataSource := DataSource1;
      DBGrid1.AutoFillColumns := true;

    except
      ShowMessage('Unable to query the database');
    end;
  end;
}

// Counts the rows of a given database table
// Not needed except for direct table interaction. The "RowCounter" function
// superseeds this and counts the actively displayed DBGrid.
{
function TfrmSQLiteDBases.GetTableRowCount(TableName : string; DBGrid : TDBGrid) : integer;
begin
  result := 0;
  try
    sqlFILES.SQL.Text := 'SELECT Count(*) FROM ' + TableName;
    SQLite3Connection1.Connected := True;
    SQLTransaction1.Active := True;
    sqlFILES.Open;
    result := sqlFILES.Fields[0].AsInteger
  except
    on E: EDatabaseError do
    begin
      MessageDlg('Error','A database error has occurred. Technical error message: ' + E.Message,mtError,[mbOK],0);
    end;
  end;
end;
}

initialization

end.

