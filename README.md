# Vectorworks-Project-Sharing-Server-Docker-One-Liner
You can use this shell script to automatically download and create a docker compose for vectorworks PSS

## Installation

Simply run the below script to install the image and create the docker compose file

**With Curl**
```sh
curl -sSL https://raw.githubusercontent.com/Morph-Tollon/Vectorworks-Project-Sharing-Server-Docker-One-Liner/refs/heads/main/installer.sh | bash
```

**With Wget**
```
wget -qO- https://raw.githubusercontent.com/Morph-Tollon/Vectorworks-Project-Sharing-Server-Docker-One-Liner/refs/heads/main/installer.sh | bash
```




## Configuration
By default, the sever will store project files and logs in the current user's home folder, however this can be changed by editing the `.env` file created during installation. e.g.
```
nano .env
```




