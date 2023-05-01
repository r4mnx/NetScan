#!/bin/bash

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
Gray='\033[1;30m'        # Gray Light
GrayL='\e[37m'             # Gray
EndC="\033[0m\e[0m"       # End colour
# Banner
echo
echo -e "${Blue}         ┏┓╻┏━╸╺┳╸┏━┓┏━╸┏━┓┏┓╻   ${EndC}"
echo -e "${Blue}         ┃┗┫┣╸  ┃ ┗━┓┃  ┣━┫┃┗┫   ${EndC}"
echo -e "${Blue}         ╹ ╹┗━╸ ╹ ┗━┛┗━╸╹ ╹╹ ╹   ${EndC}"
echo
# Indicadores
declare -i parameter_counter=0

function ctrl_c(){
  echo -e "\n\n${Red}[!] Saliendo...${White}\n"
  exit 1
}
trap ctrl_c INT

function helpPanel(){
	echo -e "\n${Yellow}[+]${Blue} Panel de uso de la aplicación: ${EndC}\n"
	echo -e "\t${Purple}p) ${GrayL}Realiza un escaneo de puertos de la IP proporcionada.${EndC}"
	echo -e "\t${Purple}o) ${GrayL}Escanea hosts \"ACTIVOS\" desde el NetworkID hasta el Broadcast de la IP/CIDR.${EndC}"
  echo -e "\t${Purple}h) ${GrayL}Muestra el panel de ayuda.${EndC}\n"
  echo -e "\t${Purple}- ${GrayL}Uso:${EndC}"
  echo -e "\t\t${Purple}- ${GrayL}./NetScan.sh -o 192.168.10/24 -> Enum HOSTS${EndC}"
  echo -e "\t\t${Purple}- ${GrayL}./NetScan.sh -p 192.168.1.100 -> Enum Ports${EndC}\n"
  exit 1
}

function portScan(){
  nameHost="$1"
  echo -e "\n${Yellow}[*]${Blue} Escaneo de puertos para la IP: ${Purple}\"${nameHost}\"${GrayL}\n"
  for port in $(seq 1 65535); do
    (echo '' > /dev/tcp/"$nameHost"/$port) 2>/dev/null && echo -ne "${Green}[+]${GrayL} Port: $port >> ${Green}OPEN${GrayL}\n"
  done
  echo -e "\n${Yellow}[*]${Blue} Escaneo finalizado.\n"
}

function hostScan(){
  nameHost="$1"
  echo -e "\n${Yellow}[*]${Blue} Escaneo de hosts${White}\n"
  for i in $(seq 1 254); do
    timeout 2 bash -c "ping -c 1 $nameHost.$i &>/dev/null" && echo -e "${Yellow}[*]${Blue} Host $nameHost.$i - ${Green}ACTIVE${EndC}" &
done; wait
  echo -e "\n${Yellow}[*]${Blue} Escaneo finalizado.${End}\n"
}

function ipcidr(){
  nameHost="$1"
  # Comprobacion IP/CIDR formato
  ip_addr="${nameHost%/*}"
  mask="${nameHost#*/}"
  if ! [[ $nameHost =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo -e "\n${Red}Error:${GrayL} Formato IP incorrecto\n'./IpCIDR.sh -h' para más ayuda.\n"
    exit 1
  fi
  for octet in $(echo $ip_addr | tr "." " "); do
    if (( $octet > 255 )); then
      echo -e "\n${Red}Error:${EndC} El valor $octet es mayor que 255.\n'./IpCIDR.sh -h' para más ayuda.\n"
      exit 1
    fi
  done
  if (( $mask < 0 || $mask > 32 )); then
    echo -e "\n${Red}Error:${EndC} Mascara de red invalida.\n'./IpCIDR.sh -h' para más ayuda.\n"
    exit 1
  fi

  spaces=$(echo "$nameHost" | tr '.\/' ' ')
  read -r -a oct <<< "$spaces"
  for ((i=0; i<4; i++)); do
    octet_bin=$(echo "obase=2;${oct[i]}" | bc)
    octbin[i]=$(printf "%08d" $octet_bin)
  done
 
  # NetMask
  cidr=${oct[4]}
  mask=$((0xffffffff << (32 - $cidr)))
  mask_oct1=$((mask >> 24 & 0xff))
  mask_oct2=$((mask >> 16 & 0xff))
  mask_oct3=$((mask >> 8 & 0xff))
  mask_oct4=$((mask & 0xff))
  mask_arr=($mask_oct1 $mask_oct2 $mask_oct3 $mask_oct4)
  for ((i=0; i<4; i++)); do
    mask_bin=$(echo "obase=2;${mask_arr[i]}" | bc)
    maskbin[i]=$(printf "%08d" $mask_bin)
  done

  # Network ID
  networkid_oct1=$((oct[0] & mask_arr[0]))
  networkid_oct2=$((oct[1] & mask_arr[1]))
  networkid_oct3=$((oct[2] & mask_arr[2]))
  networkid_oct4=$((oct[3] & mask_arr[3]))
  networkid_arr=($networkid_oct1 $networkid_oct2 $networkid_oct3 $networkid_oct4)
  for ((i=0; i<4; i++)); do
    networkid_bin=$(echo "obase=2;${networkid_arr[i]}" | bc)
    networkid_bin_arr[i]=$(printf "%08d" $networkid_bin)
  done

  # Broadcast
  inverted_mask=$((mask ^ 0xffffffff))
  broadcast_oct1=$((networkid_oct1 | (inverted_mask >> 24 & 0xff)))
  broadcast_oct2=$((networkid_oct2 | (inverted_mask >> 16 & 0xff)))
  broadcast_oct3=$((networkid_oct3 | (inverted_mask >> 8 & 0xff)))
  broadcast_oct4=$((networkid_oct4 | (inverted_mask & 0xff)))
  broadcast_arr=($broadcast_oct1 $broadcast_oct2 $broadcast_oct3 $broadcast_oct4)
  for ((i=0; i<4; i++)); do
    broadcast_bin=$(echo "obase=2;${broadcast_arr[i]}" | bc)
    broadcast_bin_arr[i]=$(printf "%08d" $broadcast_bin)
  done
  # Determinar la clase de la IP
  if [ ${oct[0]} -lt 128 ]; then
    clase="Clase A"
  elif [ ${oct[0]} -lt 192 ]; then
    clase="Clase B"
  elif [ ${oct[0]} -lt 224 ]; then
    clase="Clase C"
  elif [ ${oct[0]} -lt 240 ]; then
    clase="Clase D"
  else
    clase="Clase E"
  fi


# NumHosts
  scanIni=$(echo "${networkid_arr[@]}" | tr ' ' '.')
  scanFin=$(echo "${broadcast_arr[@]}" | tr ' ' '.')
  start=$(echo "${scanIni}" | awk -F. '{printf("%d\n", ($1*(256^3)) + ($2*(256^2)) + ($3*(256^1)) + $4)}')
  fin=$(echo "${scanFin}" | awk -F. '{printf("%d\n", ($1*(256^3)) + ($2*(256^2)) + ($3*(256^1)) + $4)}')
  resultIP=$((start - fin))
  hostNum=$(echo "$resultIP" | tr -d '-')
  resta=$(echo "$result" | tr -d '-')

# Output Info NET
  echo -e "\n${Yellow}[*]${Blue} Resultados para la IP: ${Purple}$nameHost${EndC}"
  echo -e "\n\t${Yellow}-${Green} IP: ${GrayL}$nameHost ${Green}${Green} -> ${GrayL}$clase${Green} ->${EndC} ${octbin[@]}${EndC}"
  echo -e "\t${Yellow}-${Green} Network Mask:${GrayL} ${mask_arr[@]}${Green} -> ${GrayL}${maskbin[@]}${EndC}"
  echo -e "\t${Yellow}-${Green} Network id: ${GrayL}${networkid_arr[@]}${Green} <-> ${GrayL}${networkid_bin_arr[@]}${EndC}"
  echo -e "\t${Yellow}-${Green} Broadcast: ${GrayL}${broadcast_arr[@]}${Green} <->${GrayL} ${broadcast_bin_arr[@]}"
  echo -e "\t${Yellow}-${Green} Total Hosts: ${GrayL}$hostNum\n"

  # Scan host
  echo -e "${Yellow}[*]${Blue} Escaneo de hosts${White}\n"
  newHost_arr=("${networkid_arr[@]}") # Inicializamos newHost_arr con networkid_arr
  index=${#newHost_arr[@]} # Longitud del array

  while [[ ${newHost_arr[@]} != "${broadcast_arr[@]}" ]]; do
      temp_arr=("${newHost_arr[@]}")
      ((newHost_arr[$index-1]++))
      if [ ${newHost_arr[$index-1]} -eq 256 ]; then
          for (( i=$index-1; i>=0; i-- )); do
              if [ ${newHost_arr[$i]} -eq ${broadcast_arr[$i]} ]; then
                  break
              elif [ ${newHost_arr[$i]} -eq 256 ]; then
                  newHost_arr[$i]=0
                 ((newHost_arr[$i-1]++))
              else
                  break
              fi
          done
      fi
      for (( i=0; i<$index-1; i++ )); do
          if [ ${newHost_arr[$i]} -eq ${temp_arr[$i]} ]; then
              newHost_arr[$i]=${temp_arr[$i]}
          fi
      done
      if [ ${#newHost_arr[@]} -gt 4 ]; then
          newHost_arr=("${newHost_arr[@]:1}")
      fi
    ipscan=$(echo ${newHost_arr[@]} | tr ' ' '.')
    timeout 2 bash -c "ping -c 1 ${ipscan} &>/dev/null" && echo -e "${Green}[+]${Blue} Host${GrayL} ${ipscan} - ${Green}ACTIVE${EndC}" &
done; wait
  echo -e "\n${Yellow}[*]${Blue} Escaneo finalizado.${End}\n"
}

while getopts "p:o:h" arg; do
  case $arg in
	  p) nameHost="$OPTARG"; let parameter_counter+=1;;
    o) nameHost="$OPTARG"; let parameter_counter+=2;; 
    h) helpPanel;;
  esac
done

if [ $parameter_counter -eq 1 ]; then
  portScan $nameHost
elif [ $parameter_counter -eq 2 ]; then
	ipcidr $nameHost
else
	echo -e "\n${Red}[+] Comando o datos incorrectos: ${GrayL}NetScan.sh -h para mostrar panel de ayuda.${EndC}"
fi
