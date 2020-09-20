import sys

def read_key(msg_num):
    with open("sdi.txt", 'r') as key:
        key_data=key.read()
    for line in key_data.split("####"):
#         print(f" MsgID=%3s" % msg_num)
#         print(line)
        if f"MsgID=%3s" % msg_num in line:
            array = line.splitlines()
            key  = array[-2].split("= ")[1]
            print("key: ", end=" ")
            i = 0
            while(i < len(key)):
                print(f"0x{key[i:i+2]}", end=", ")
                i += 2
            break
    print("")
def read_pid(msg_num):
    with open("pdi.txt", 'r') as pdi:
        pdi_data = pdi.read()
    for line in pdi_data.split('####'):
        ad = None
        plaintext = None
        ctext =None
        if f"MsgID=%3s" % msg_num in line:
            data = line.splitlines()
            print(data)
            for i in range(len(data)):
                if "HDR = D" in data[i]:
                    print_content("npub", data, i)
                if "HDR = 1" in data[i]:
                    print_content("ad", data, i)
                if "HDR = 4" in data[i]:
                    print_content("pt", data, i)
                        
                if "HDR = 5" in data[i]:
                    print_content("ct", data, i)
                if "HDR = 7" in data[i]:
                    print_content("hash", data, i)
                if "HDR = 8" in data[i]:
                    try:
                        TAG = data[i+1].split("= ")[1]
                    except IndexError:
                        pass
                    if TAG:
                        x = 0
                        print("\nTAG: ", end=" ")
                        while(x < len(TAG)):
                            print(f"0x{TAG[x:x+2]}", end=", ")
                            x +=2
                        print("")
            break
        
def print_content(name, data, i):
    p = 0
    while (True):
        p+=1
        try:
            plaintext = data[i+p].split( "= ")[1]
        except IndexError:
            return
        if plaintext:
            x = 0
            print(f"\n{name}: ", end=" ")
            while(x < len(plaintext)):
                print(f"0x{plaintext[x:x+2]}", end=", ")
                x +=2    
        print("")
if __name__ == "__main__":
    if sys.argv[1].upper() == "HASH":
        read_pid(sys.argv[2])
    else:
        read_key(sys.argv[2])  
        print("") 
        read_pid(sys.argv[1])
