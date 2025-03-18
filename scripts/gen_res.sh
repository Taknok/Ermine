#!/bin/bash

cp -r ermine-artwork/* fenix-artwork/
rm -r ermine-artwork/

pushd fenix-artwork
make
popd
