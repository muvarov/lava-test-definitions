import io
import pathlib
import pycdlib
import sys, getopt


inputfile = ''
outputfile = ''

def getargs(argv):
   global inputfile
   global outputfile
   try:
      opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
   except getopt.GetoptError:
      print ('%s -i <inputfile> -o <outputfile>' % sys.argv[0])
      sys.exit(2)
   if not opts:
      print ('%s -i <inputfile> -o <outputfile>' % sys.argv[0])
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print ('%s -i <inputfile> -o <outputfile>' % sys.argv[0])
         sys.exit(2)
      elif opt in ("-i", "--ifile"):
         inputfile = arg
      elif opt in ("-o", "--ofile"):
         outputfile = arg
   print ('Input file is "', inputfile)
   print ('Output file is "', outputfile)

if __name__ == "__main__":
   getargs(sys.argv[1:])


ubuntu = pathlib.Path(inputfile)
new_iso = pathlib.Path(outputfile)

iso = pycdlib.PyCdlib()
iso.open(ubuntu)

extracted = io.BytesIO()
iso.get_file_from_iso_fp(extracted, iso_path='/BOOT/GRUB/GRUB.CFG;1')
extracted.seek(0)
data = extracted.read()
print(data.decode())

new = data.replace(b' ---', b' autoinstall ---').replace(b'timeout=30', b'timeout=1')
print(new.decode())

iso.rm_file(iso_path='/BOOT/GRUB/GRUB.CFG;1', rr_name='grub.cfg')
iso.add_fp(io.BytesIO(new), len(new), '/BOOT/GRUB/GRUB.CFG;1', rr_name='grub.cfg')

iso.write(new_iso)
iso.close()
