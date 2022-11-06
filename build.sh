#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc \
      sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc x86_64-macos-darwin-gcc \
      arm64-macos-darwin-cc x86_64-freebsd-gnu-gcc x86_64-solaris-gnu-gcc armv6-linux-gnueabi-gcc"

declare -A alias=( [x86-linux-gnu-gcc]=i686-stretch-linux-gnu-gcc \
                   [x86_64-linux-gnu-gcc]=x86_64-stretch-linux-gnu-gcc \
                   [arm-linux-gnueabi-gcc]=armv7-stretch-linux-gnueabi-gcc \
                   [armv6-linux-gnueabi-gcc]=armv6-stretch-linux-gnueabi-gcc \
                   [aarch64-linux-gnu-gcc]=aarch64-stretch-linux-gnu-gcc \
                   [sparc64-linux-gnu-gcc]=sparc64-stretch-linux-gnu-gcc \
                   [mips-linux-gnu-gcc]=mips64-stretch-linux-gnu-gcc \
                   [powerpc-linux-gnu-gcc]=powerpc64-stretch-linux-gnu-gcc \
                   [x86_64-macos-darwin-gcc]=x86_64-apple-darwin19-gcc \
                   [arm64-macos-darwin-cc]=arm64-apple-darwin20.4-cc \
                   [x86_64-freebsd-gnu-gcc]=x86_64-cross-freebsd12.3-gcc \
                   [x86_64-solaris-gnu-gcc]=x86_64-cross-solaris2.x-gcc )

declare -A cflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" \
                    [mips-linux-gnu-gcc]="-march=mips32" \
                    [powerpc-linux-gnu-gcc]="-m32" )
					
declare -a compilers

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}; do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		if command -v $cc &> /dev/null; then
			unset alias[$cc]
		else	
			continue
		fi	
	fi

	if [[ $# == 0 || ($# == 1 && -n $clean) ]]; then
		compilers+=($cc)
		continue
	fi

	for arg in $@
	do
		if [[ $cc =~ $arg ]]; then 
			compilers+=($cc)
		fi
	done
done

declare -A config=( [arm-linux]=linux-armv4 \
                    [armv6-linux]=linux-armv4 \
                    [mips-linux]=linux-generic32 \
                    [sparc64-linux]=linux64-sparcv9 \
                    [powerpc-linux]=linux-ppc \
                    [x86_64-macos]=darwin64-x86_64-cc \
                    [arm64-macos]=darwin64-arm64-cc \
                    [x86_64-freebsd]=BSD-x86_64 \
                    [x86_64-solaris]=solaris64-x86_64-gcc )

library=libopenssl.a
 
# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	target=targets/$host/$platform
	
	if [[ -f $target/$library && -z $clean ]]; then
		continue
	fi

	pushd openssl	
	export CFLAGS=${cflags[$cc]}
	export CC=${alias[$cc]:-$cc}
	export AR=${CC%-*}-ar
	export RANLIB=${CC%-*}-ranlib
	if [[ $CC =~ -gcc ]]; then
		export CXX=${CC%-*}-g++
	else
		export CXX=${CC%-*}-c++
		CFLAGS+=" -fno-temp-file -stdlib=libc++"
	fi	
	
	./Configure no-shared ${config["$platform-$host"]:-"$host-$platform"}
	make clean && make -j8
	popd
	
	# includes
	mkdir -p $target
	cp openssl/lib*.a $_
	
	# libraries (beware $_)
	mkdir -p $_/include
	cp -ur openssl/include/openssl/ $_
	cp -ur openssl/include/crypto/ $_
	find $_ -type f -not -name "*.h" -exec rm {} +	
	
	# concatenate all in a thin (if possible)
	rm -f $target/$library
	if [[ $host =~ macos ]]; then
		${CC%-*}-libtool -static -o $target/$library $target/*.a 		
	else
		ar -rc --thin $target/$library $target/*.a 
	fi
done


