import sys
import importlib.metadata

print("This is sample code!!")
print("Running Python executable at:")
print(f"  {sys.executable}")

print("Installed packages:")
for dist in importlib.metadata.distributions():
    print(f"  {dist.metadata['Name']}=={dist.version}")
