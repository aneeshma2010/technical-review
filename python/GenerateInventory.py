import json

class Host:
    def __init__(self, ip, user, ssh_key):
        self.ip = ip
        self.user = user
        self.ssh_key = ssh_key

    def inventoryFormat(self):
        return f"{self.ip} ansible_user={self.user} ansible_ssh_private_key_file={self.ssh_key}"


class HostObjects:
    @staticmethod
    def createClass(data):
        return Host(
            ip=data.get("ip"),
            user=data.get("user"),
        )


class ansInventory:
    def __init__(self, json_file, inventory_file="inventory.ini"):
        self.json_file = json_file
        self.inventory_file = inventory_file

    def generateInventory(self):
        with open(self.json_file, r) as f:
            hosts_json = json.load(f)

        hosts = [HostObjects.createClass(h) for h in hosts_json]

        with open(self.inventory_file, "w") as f:
            for host in hosts:
                f.write(host.inventoryFormat() + "\n")

        print(f"Inventory successfully created at: {self.inventory_file}")


if __name__ == "__main__":
    inventory = ansInventory("input.json")
    inventory.generateInventory()
