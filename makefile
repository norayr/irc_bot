
VOC = /opt/voc/bin/voc

all:
	$(VOC) -s lists/src/Sys.Mod lists/src/strutils.Mod lists/src/List.Mod lists/src/StringList.Mod
	$(VOC) -s types.Mod sockets.Mod netdb.Mod Internet.Mod stringHelpers.Mod time.Mod IRC.Mod test.Mod -m

clean:
	rm *.h
	rm *.c
	rm *.o
	rm *.sym
