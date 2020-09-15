import sys
x=sys.argv[1]
z=""
print(x)
for y in range(len(x)):
    if y%2 ==0:
        z+="0x"+x[y:y+2]+","
print(z)
