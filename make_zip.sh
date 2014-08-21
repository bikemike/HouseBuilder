#! /bin/sh
rm mm_HouseBuilder.rbz
cd src
if [ $1 = "src" ] ; then
	zip -r ../mm_HouseBuilder.rbz *rb mm_HouseBuilder/*rb mm_HouseBuilder/*png 
else
	wine ../SketchUpRubyScramblerWindows.exe *rb mm_HouseBuilder/*rb
	zip -r ../mm_HouseBuilder.rbz *rbs mm_HouseBuilder/*rbs mm_HouseBuilder/*png 
fi
