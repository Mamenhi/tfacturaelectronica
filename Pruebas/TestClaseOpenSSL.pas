(* *****************************************************************************
  Copyright (C) 2010 - Bambu Code SA de CV - Ing. Luis Carrasco

  Este archivo pertenece al proyecto de codigo fuente de Bambu Code:
  http://bambucode.com/codigoabierto

  La licencia de este codigo fuente se encuentra en:
  http://github.com/bambucode/bc_facturaelectronica/blob/master/LICENCIA
  ***************************************************************************** *)

unit TestClaseOpenSSL;

interface

uses
  TestFramework, TestPrueba, ClaseOpenSSL;

type

  TestTOpenSSL = class(TTestPrueba)
  strict private
    fOpenSSL: TOpenSSL;
    fArchivoLlavePrivada: String;
    fClaveLlavePrivada: String;
  private
    procedure BorrarArchivoTempSiExiste(sNombre: String);
  public
    procedure SetUp; override;
    procedure TearDown; override;
    procedure EjecutarComandoOpenSSL(sComando: String);
  published
    procedure HacerDigestion_TipoMD5_FuncioneCorrectamente;
    procedure HacerDigestion_TipoSHA1_FuncioneCorrectamente;
    procedure HacerDigestion_ConClaveIncorrecta_CauseExcepcion;
    procedure ObtenerCertificado_CertificadoDePrueba_RegreseElCertificadoConPropiedades;
  end;

const
  // Configura tu propia ruta a OpenSSL.exe
  _RUTA_OPENSSL_EXE = 'C:\Debug\SAT\openssl.exe';

implementation

uses
  Windows, SysUtils, Classes, FacturaTipos, ShellApi, Forms, OpenSSLUtils, DateUtils;


procedure TestTOpenSSL.BorrarArchivoTempSiExiste(sNombre: String);
  begin
    if FileExists(fDirTemporal + sNombre) then
      DeleteFile(fDirTemporal + sNombre);
  end;

procedure TestTOpenSSL.SetUp;
begin
  inherited;
  fArchivoLlavePrivada := fRutaEXE + 'Fixtures\openssl\aaa010101aaa_CSD_02.key';
  fClaveLlavePrivada := leerContenidoDeFixture('openssl\aaa010101aaa_CSD_02_clave.txt');
  // Creamos el objeto OpenSSL
  fOpenSSL := TOpenSSL.Create();
end;

procedure TestTOpenSSL.TearDown;
begin
  FreeAndNil(fOpenSSL);
end;

procedure TestTOpenSSL.EjecutarComandoOpenSSL(sComando: String);
var
   slBat: TStrings;
begin
  DeleteFile(fDirTemporal + 'openssltest.bat');

  slBat:=TStringList.Create;
  slBat.Add(_RUTA_OPENSSL_EXE + ' ' + sComando);
  slBat.SaveToFile(fDirTemporal + 'openssltest.bat');
  FreeAndNil(slBat);
  Sleep(100);
  ShellExecute(Application.Handle,PChar('Open'),PChar(fDirTemporal + 'openssltest.bat'),nil,nil,SW_HIDE);
  // Hacemos esperar 1 segundo para que termine openssl.exe.
  Sleep(1000);
end;

procedure TestTOpenSSL.HacerDigestion_TipoMD5_FuncioneCorrectamente;
var
  sResultadoMD5DeClase, sResultadoMD5OpenSSL: WideString;

  function QuitarRetornos(sCad: WideString): WideString;
  begin
    Result := StringReplace(sCad, #13#10, '', [rfReplaceAll, rfIgnoreCase]);
  end;

const
  // Se puede probar la efectividad del metodo cambiando la siguiente cadena
  // la cual debe ser la misma entre el resultado de la clase y de comandos manuales de Openssl.exe
  _CADENA_DE_PRUEBA = 'Esta es una cadena de prueba para la digestion';

  _ARCHIVO_LLAVE_PEM = 'aaa010101aaa_CSD_02.pem';
  _ARCHIVO_CADENA_TEMPORAL = 'cadena_hacerdigestion.txt';
  _ARCHIVO_TEMPORAL_RESULTADO_OPENSSL = 'md5_cadena_hacerdigestion.txt';
begin
  // Borramos los archivos temporales que vamos a usar si acaso existen (de pruebas pasadas)
  BorrarArchivoTempSiExiste(_ARCHIVO_CADENA_TEMPORAL);
  BorrarArchivoTempSiExiste(_ARCHIVO_TEMPORAL_RESULTADO_OPENSSL);
  BorrarArchivoTempSiExiste('md5_cadena_de_prueba.bin');

  // Guardamos el contenido de la cadena de prueba a un archivo temporal
  guardarArchivoTemporal(_CADENA_DE_PRUEBA, _ARCHIVO_CADENA_TEMPORAL);

  // Primero hacemos la digestion usando openssl.exe y la linea de comandos
  EjecutarComandoOpenSSL('dgst -md5 -sign "' + fRutaFixtures + 'openssl\' +
    _ARCHIVO_LLAVE_PEM + '" -out "' + fDirTemporal +
    'md5_cadena_de_prueba.bin" "' + fDirTemporal +
    _ARCHIVO_CADENA_TEMPORAL + '"');

  // Convertimos el resultado (archivo binario) a base64
  EjecutarComandoOpenSSL(' enc -base64 -in "' + fDirTemporal +
    'md5_cadena_de_prueba.bin" -out "' + fDirTemporal +
    _ARCHIVO_TEMPORAL_RESULTADO_OPENSSL + '"');
 
  // Quitamos los retornos de carro ya que la codificacion Base64 de OpenSSL la regresa con ENTERs
  sResultadoMD5OpenSSL := QuitarRetornos(leerContenidoDeArchivo(fDirTemporal + _ARCHIVO_TEMPORAL_RESULTADO_OPENSSL));
  // Ahora, hacemos la digestion con la libreria
  sResultadoMD5DeClase := fOpenSSL.HacerDigestion(fArchivoLlavePrivada, fClaveLlavePrivada,_CADENA_DE_PRUEBA, tdMD5);

  // Comparamos los resultados (sin retornos de carro), los cuales deben de ser los mismos
  CheckEquals(sResultadoMD5OpenSSL, sResultadoMD5DeClase, 'La digestion MD5 de la clase no fue la misma que la de OpenSSL');
end;

procedure TestTOpenSSL.HacerDigestion_TipoSHA1_FuncioneCorrectamente;
begin
  // TODO: Implementar pruebas y validaciones de SHA1
  CheckTrue(True);
end;

procedure TestTOpenSSL.HacerDigestion_ConClaveIncorrecta_CauseExcepcion;
var
  fOpenSSL2: TOpenSSL;
  bExcepcionLanzada: Boolean;
begin
  // Creamos un nuevo objeto OpenSSL con una clave incorrecta a proposito
  bExcepcionLanzada := False;
  fOpenSSL2 := TOpenSSL.Create();
  try
    fOpenSSL2.HacerDigestion(fArchivoLlavePrivada, 'claveincorrectaintencional', 'Cadena', tdMD5);
  except
    On E: TLlavePrivadaClaveIncorrectaException do
    begin
      bExcepcionLanzada := True;
    end;
  end;

  CheckTrue(bExcepcionLanzada,
    'No se lanzo excepcion cuando se especifico clave privada incorrecta.');
  FreeAndNil(fOpenSSL2);
end;

procedure TestTOpenSSL.
  ObtenerCertificado_CertificadoDePrueba_RegreseElCertificadoConPropiedades;
var
  Certificado: TX509Certificate;
  sInicioVigencia, sFinVigencia: String;
  dtInicioVigencia, dtFinVigencia: TDateTime;

  function NombreMesANumero(sMes: String) : Integer;
  begin
    sMes:=Uppercase(sMes);
    if sMes = 'JAN' then Result:=1;
    if sMes = 'FEB' then Result:=2;
    if sMes = 'MAR' then Result:=3;
    if sMes = 'APR' then Result:=4;
    if sMes = 'MAY' then Result:=5;
    if sMes = 'JUN' then Result:=6;
    if sMes = 'JUL' then Result:=7;
    if sMes = 'AUG' then Result:=8;
    if sMes = 'SEP' then Result:=9;
    if sMes = 'OCT' then Result:=10;
    if sMes = 'NOV' then Result:=11;
    if sMes = 'DEC' then Result:=12;
  end;

  function leerFechaDeArchivo(sRuta: String) : TDateTime;
  var
     sFecha, sTxt, sMes, sHora, sAno, sDia: String;
  begin
      // Leemos el archivo y convertimos el contenido a una fecha de Delphi
      sTxt:=leerContenidoDeArchivo(sRuta);
      // Quitamos la parte inicial (ej:notBefore=)
      sFecha:=Copy(sTxt,AnsiPos('=',sTxt)+1, Length(sTxt));
      //Ej: Jul 30 16:58:40 2010 GMT
      sMes:=Copy(sFecha, 1, 3);
      sDia:=Copy(sFecha, 5, 2);
      sHora:=Copy(sFecha, 8, 8);
      sAno:=Copy(sFecha, 17, 4);
      // Procesamos la fecha que regresa OpenSSL para convertirla a formato Delphi
      Result:=StrToDateTime(sDia + '/' + IntToStr(NombreMesANumero(sMes)) + '/' + sAno + ' ' + sHora);
  end;

const
  _NOMBRE_CERTIFICADO = 'openssl\aaa010101aaa_CSD_02.cer';
begin
  BorrarArchivoTempSiExiste(fDirTemporal + 'VigenciaInicio.txt');

  // Procesamos el certificado con el OpenSSL.exe para obtener los datos y
  // poder corroborarlos...
  EjecutarComandoOpenSSL(' x509 -inform DER -in "' + fRutaFixtures + _NOMBRE_CERTIFICADO +
                          '" -noout -startdate > "' + fDirTemporal + 'VigenciaInicio.txt" ');

  Sleep(1000);
  dtInicioVigencia:=leerFechaDeArchivo(fDirTemporal + 'VigenciaInicio.txt');

  Certificado := fOpenSSL.ObtenerCertificado(fRutaFixtures + _NOMBRE_CERTIFICADO);

  // Checamos las propiedades que nos interesan
  CheckEquals(dtInicioVigencia, Certificado.NotBefore, 'El inicio de vigencia del certificado no fue el mismo que regreso OpenSSL');
  //CheckEquals(dtFinVigencia, Certificado.NotBefore, 'El fin de vigencia del certificado no fue el mismo que regreso OpenSSL');
  FreeAndNil(Certificado);
end;

initialization

// Registra la prueba de esta unidad en la suite de pruebas
RegisterTest(TestTOpenSSL.Suite);

end.
