setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"

cd openssl
perl Configure shared VC-WIN32
nmake
cd ..

set target=targets\win32\x86

if exist %target% (
	del %target%\*.lib
)
	
robocopy openssl %target% lib*_static.lib lib*.pdb lib*.dll /NDL /NJH /NJS /nc /ns /np
robocopy openssl\include %target%\include *.h /S /XD internal /NDL /NJH /NJS /nc /ns /np
lib.exe /OUT:%target%/libopenssl.lib %target%/libcrypto_static.lib %target%/libssl_static.lib

endlocal
