#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc"
declare -A alias=( [x86-linux-gnu-gcc]=i686-linux-gnu-gcc )
declare -A cppflags=( [mips-linux-gnu-gcc]="-march=mips32" [powerpc-linux-gnu-gcc]="-m32" )
declare -a compilers

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}
do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		continue
	fi
	
	if [[ $# == 0 ]]; then
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

declare -A config=( [arm-linux]=linux-armv4 [mips-linux]=linux-mips32 [sparc64-linux]=linux64-sparcv9 [powerpc-linux]=linux-ppc )
library=libopenssl.a
 
# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc
	
	if [[ -f $target/$library && -z $clean ]]; then
		continue
	fi

	pwd=$(pwd)
	cd openssl	
	export CPPFLAGS=${cppflags[$cc]}
	export CC=${alias[$cc]:-$cc}
	export CXX=${CC/gcc/g++}	
	./Configure no-shared ${config["$platform-$host"]:-"$host-$platform"}
	make clean && make
	cd $pwd
	
	target=targets/$host/$platform
	mkdir -p $target
	cp openssl/lib*.a $_
	mkdir -p $_/include
	cp -ur openssl/include/openssl/ $_
	cp -ur openssl/include/crypto/ $_
	find $_ -type f -not -name "*.h" -exec rm {} +	
	ar -rc --thin $target/$library $target/libcrypto.a 
	ar -rc --thin $target/$library $target/libssl.a 
done


