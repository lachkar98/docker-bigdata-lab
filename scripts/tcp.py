import socket, sys
with socket.create_connection((sys.argv[1],int(sys.argv[2])),timeout=3): pass
