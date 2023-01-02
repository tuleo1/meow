# find base and update NSPs
basensp=$(ls -S *.nsp | head -1)
updatensp=$(ls -Sr *.nsp | head -1)

mkdir -p ~/.switch
cp prod.keys ~/.switch
touch ~/.switch/title.keys

mkdir temp hactool_out
cd hactool_out

# derive title keys from base and update NSPs
derivekey () {
	title=$(xxd *.tik | grep -oP -m 1 "(?<=2a0: ).{39}" | sed 's/ //g')
	key=$(xxd *.tik | grep -oP -m 1 "(?<=180: ).{39}" | sed 's/ //g')
	sed -i "/$title=$key/d" ~/.switch/title.keys
	echo $title=$key >> ~/.switch/title.keys
}
../hactool -t pfs0 "../$basensp" --outdir .

derivekey

for i in *.nca
do
	type=$(../hactool $i | grep -oP "(?<=Content Type:\s{23}).*")
	if [ $type == "Program" ]; then
		basenca=$i
		mv $i ../temp
	fi
done
rm *

../hactool -t pfs0 "../$updatensp" --outdir .

derivekey

for i in *.nca
do
	type=$(../hactool $i | grep -oP "(?<=Content Type:\s{23}).*")
	if [ $type == "Program" ]; then
		updatenca=$i
		mv $i ../temp
	elif [ $type == "Control" ]; then
		controlnca=$i
		mv $i ../temp
	fi
done
rm *

cd ..
rm -rf hactool_out

cp hactool temp/
cp hacpack temp/
cd temp

# parse Title ID from base program NCA
titleid=$(./hactool $basenca | grep -oP "(?<=Title ID:\s{27}).*")

# extract base and update NCAs into romfs end exefs
mkdir exefs romfs
./hactool --basenca="$basenca" $updatenca --romfsdir="romfs" --exefsdir="exefs"

# pack romfs and exefs into one NCA
mkdir nca
./hacpack --type="nca" --ncatype="program" --plaintext --exefsdir="exefs" --romfsdir="romfs" --titleid="$titleid" --outdir="nca"
patchednca=$(ls nca)
mv $controlnca nca

# generate meta NCA from patched NCA and control NCA
./hacpack --type="nca" --ncatype="meta" --titletype="application" --programnca="nca/$patchednca" --controlnca="nca/$controlnca" --titleid="$titleid" --outdir="nca"

# pack all three NCAs into an NSP
mkdir nsp
./hacpack --type="nsp" --ncadir="nca" --titleid="$titleid" --outdir="nsp"

cd ..
mv temp/nsp/$titleid.nsp ./$titleid[patched].nsp
