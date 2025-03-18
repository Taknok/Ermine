#!/bin/bash

cp -r ermine-artwork fenix-artwork

pushd fenix-artwork
make
popd
