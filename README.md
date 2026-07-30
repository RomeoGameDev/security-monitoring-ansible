# Security Monitoring – Ansible

Kompletne wdrożenie dla:

- Ubuntu 24.04+
- Debian 13+

Instaluje:

- Docker Engine i Docker Compose
- Wazuh 4.14.6 single-node
- reguły i dekodery SOCFortress
- obsługę własnych reguł i dekoderów Wazuh
- Zabbix 7.0 LTS: Server, frontend Nginx i MySQL
- Zabbix Agent 2 bezpośrednio na hoście
- Nginx Proxy Manager
- bramę ścieżkową Nginx

## Adresy

Po wdrożeniu:

```text
http://IP/wazuh/
http://IP/zabbix/
http://IP:81
```

Porty usług:

```text
Wazuh events:       1514/TCP
Wazuh enrollment:   1515/TCP
Wazuh API:          55000/TCP
Zabbix server:      10051/TCP
Zabbix Agent 2:     10050/TCP
NPM HTTPS:          443/TCP
```

Port `80` obsługuje brama ścieżkowa. Ruch domenowy, który nie pasuje do
`/wazuh` ani `/zabbix`, jest przekazywany do Nginx Proxy Managera.

## Wymagania

Rekomendowane minimum:

- 4 vCPU
- 8 GB RAM
- 40 GB wolnego miejsca
- użytkownik `ansible` z dostępem do `sudo`

## Konfiguracja przed uruchomieniem

Edytuj:

```text
inventory.yml
group_vars/all.yml
```

W `group_vars/all.yml` koniecznie zmień hasła oznaczone `CHANGE_ME`.

Adres Zabbix Server ustawiany w Agent 2:

```yaml
zabbix_agent_server_address: "127.0.0.1"
```

Dla serwera Zabbix uruchomionego lokalnie pozostaw `127.0.0.1`.
Dla zewnętrznego serwera wpisz jego adres IP lub DNS.

## Uruchomienie

```bash
chmod +x run.sh cleanup_fresh.sh
./run.sh
```

Nie trzeba uruchamiać skryptu czyszczącego przed ponownym wykonaniem playbooka.

## Wazuh Dashboard – zapis konfiguracji

Plik:

```text
/opt/wazuh-persistent/dashboard/wazuh.yml
```

jest montowany do Dashboardu jako `RW`. Zmiany wykonane w GUI, np. adres
używany w instrukcji wdrażania agentów, pozostają po restarcie i ponownym
uruchomieniu playbooka.

Konfiguracja bazowej ścieżki Dashboardu jest zarządzana przez Ansible:

```text
/wazuh
```

## Własne detekcje Wazuh

Reguły:

```text
files/wazuh/custom_rules/*.xml
```

Dekodery:

```text
files/wazuh/custom_decoders/*.xml
```

Katalogi mogą być puste. Po dodaniu lub usunięciu plików uruchom:

```bash
./run.sh
```

Playbook używa manifestów, dlatego usuwa z Wazuh także stare pliki,
które wcześniej wdrożył, a następnie usunięto je z katalogu źródłowego.

Nie twórz pustego pliku XML zawierającego wyłącznie pustą grupę Wazuh.

## Zabbix

Frontend działa na oficjalnym obrazie:

```text
zabbix/zabbix-web-nginx-mysql:alpine-7.0-latest
```

Baza ma trwale ustawione:

```text
log_bin_trust_function_creators=1
```

Plik konfiguracyjny:

```text
/opt/zabbix/mysql-zabbix.cnf
```

Domyślne konto Zabbix:

```text
Login: Admin
Hasło: zabbix
```

Po zalogowaniu zmień hasło.

### Dodanie lokalnego hosta do Zabbixa

Agent 2 jest instalowany i uruchamiany automatycznie. W GUI Zabbixa dodaj
host z nazwą zgodną z hostname systemu.

Dla sprawdzania pasywnego użyj:

```text
Interfejs: Agent
DNS: host.docker.internal
Port: 10050
Connect to: DNS
```

Możesz także użyć adresu IP hosta.

Użytkownik `zabbix` jest dodawany do grupy `docker`, dzięki czemu Agent 2
może monitorować kontenery przez `/var/run/docker.sock`.

## Kontrola

```bash
sudo docker ps

sudo docker exec single-node-wazuh.manager-1 \
  /var/ossec/bin/wazuh-analysisd -t

systemctl status zabbix-agent2

sudo docker exec zabbix-db \
  mysql -uroot -p -e \
  "SHOW VARIABLES LIKE 'log_bin_trust_function_creators';"
```

Brak wyniku z `wazuh-analysisd -t` oznacza poprawną konfigurację.

## Nginx Proxy Manager

Panel:

```text
http://IP:81
```

NPM nasłuchuje bezpośrednio na porcie `443`. Ruch HTTP na porcie `80`
najpierw trafia do bramy ścieżkowej. Pozostałe hosty i ścieżki są przekazywane
do NPM z zachowaniem nagłówka `Host`.

## Pełne czyszczenie

```bash
sudo ./cleanup_fresh.sh
```

Skrypt usuwa kontenery, wolumeny i dane Wazuh, Zabbix oraz NPM.
Docker i Zabbix Agent 2 na hoście pozostają zainstalowane.
