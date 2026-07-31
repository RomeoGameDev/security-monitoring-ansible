# Security Monitoring – Ansible

Wdrożenie dla Ubuntu 24.04+ i Debian 13+.

Instaluje Docker, Wazuh 4.14.6 single-node, SOCFortress, Zabbix 7.0 LTS, Zabbix Agent 2 na hoście, Nginx Proxy Manager oraz jedną wspólną MariaDB dla NPM i Zabbixa.

Nie ma dodatkowego publicznego gatewaya. Porty 80 i 443 obsługuje wyłącznie Nginx Proxy Manager.

## Architektura

```text
MariaDB
├── baza npm
└── baza zabbix

Nginx Proxy Manager
├── /          -> przekierowanie do /zabbix/
├── /zabbix/   -> zabbix-web-nginx:8080
└── /wazuh/    -> wazuh-dashboard:5601
```

Kontenery:

```text
shared-db
nginx-proxy-manager
wazuh-manager
wazuh-indexer
wazuh-dashboard
zabbix-server
zabbix-web-nginx
```

Zabbix Agent 2 działa jako usługa systemowa na hoście.

## Przygotowanie

```bash
cp group_vars/all.yml.example group_vars/all.yml
chmod 600 group_vars/all.yml
nano group_vars/all.yml
chmod +x run.sh cleanup_fresh.sh
./run.sh
```

`group_vars/all.yml` jest ignorowany przez Git. Plik przykładowy zawiera proste hasła laboratoryjne. Hasła baz danych nie wymagają znaków specjalnych. NPM wymaga jedynie hasła administratora o długości 8–64 znaków.

## Aktualizacja z V4

Przy aktualizacji działającej instalacji nie uruchamiaj `cleanup_fresh.sh`. Zachowaj swój plik z hasłami, podmień pliki projektu i uruchom playbook ponownie:

```bash
cp group_vars/all.yml /tmp/security-monitoring-all.yml
# podmień pliki projektu na V5
cp /tmp/security-monitoring-all.yml group_vars/all.yml
chmod 600 group_vars/all.yml
./run.sh
```

Starszy `group_vars/all.yml` może nie zawierać nowych zmiennych TLS. Playbook przyjmie wtedy domyślnie: self-signed włączony, 3650 dni i bez `Force SSL`.

V5 używa nowych markerów provisioningu, dlatego zaktualizuje istniejący Proxy Host do ścieżek `/zabbix/` i `/wazuh/` oraz ponowi bezpieczną próbę ustawienia interfejsu Agenta na IP VM.

## Adresy

```text
Zabbix HTTP:           http://IP/zabbix/
Wazuh HTTP:            http://IP/wazuh/
Zabbix HTTPS:          https://IP/zabbix/
Wazuh HTTPS:           https://IP/wazuh/
Nginx Proxy Manager:   http://IP:81
```

`/` przekierowuje do `/zabbix/`.

## Self-signed dla IP

Domyślnie playbook generuje certyfikat self-signed z SAN zawierającym adres IP VM i dodaje go do NPM jako:

```text
Security Monitoring self-signed IP
```

Pliki certyfikatu:

```text
/opt/nginx-proxy-manager/certificates/monitoring-IP.crt
/opt/nginx-proxy-manager/certificates/monitoring-IP.key
```

Ustawienia:

```yaml
npm_self_signed_enabled: true
npm_self_signed_days: 3650
npm_force_ssl: false
```

HTTP i HTTPS działają równolegle. Przeglądarka pokaże ostrzeżenie, dopóki certyfikat lub wewnętrzny urząd CA nie zostanie dodany do zaufanych. Po dodaniu domeny w NPM można podpiąć certyfikat publiczny; provisioner nie zastępuje certyfikatu dodanego ręcznie.

## Domyślne dane logowania

```text
Wazuh:
  login: admin
  hasło: SecretPassword

Zabbix:
  login: Admin
  hasło: zabbix

Nginx Proxy Manager:
  login: admin@example.com
  hasło: changeme
```

Domyślne hasła wewnętrzne baz:

```text
MariaDB root: rootpassword
NPM DB:       npmpassword
Zabbix DB:    zabbixpassword
```

## Zabbix pod `/zabbix/`

NPM usuwa prefiks `/zabbix/` przed przekazaniem żądania do oficjalnego obrazu `zabbix-web-nginx`. Przekierowania odpowiedzi oraz ścieżka ciasteczka sesyjnego są przepisywane na `/zabbix/`.

Jest to istotne, ponieważ bez poprawienia ścieżki ciasteczka logowanie przez reverse proxy może kończyć się komunikatem `You are not logged in`.

## Ważne: interfejs Agenta hosta `Zabbix server`

Po wdrożeniu sprawdź w Zabbix Web:

```text
Data collection -> Hosts -> Zabbix server -> Interfaces
```

Interfejs Agent powinien wskazywać:

```text
IP:   adres IP VM, np. 10.100.0.32
Port: 10050
```

Nie zostawiaj:

```text
127.0.0.1:10050
```

Dla kontenera `zabbix-server` adres `127.0.0.1` oznacza sam kontener, a Agent 2 działa na hoście. Playbook próbuje jednorazowo ustawić adres IP VM przez API, ale po wdrożeniu należy to skontrolować w GUI.

Konfiguracja Agenta 2 na hoście może pozostać:

```ini
Server=127.0.0.1,172.16.0.0/12
ServerActive=127.0.0.1
Hostname=Zabbix server
ListenIP=0.0.0.0
ListenPort=10050
```

Zakres `172.16.0.0/12` obejmuje dynamiczne adresy kontenerów, np. `172.19.0.5` i `172.21.0.2`. Nie wpisuj pojedynczego IP kontenera, ponieważ może się zmienić po jego odtworzeniu.

Kontrola:

```bash
systemctl status zabbix-agent2 --no-pager
ss -lntp | grep ':10050'
docker inspect -f '{{range $name,$net := .NetworkSettings.Networks}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}' zabbix-server
```

## Dostęp WWW tylko przez NPM

Frontend Zabbixa i Wazuh Dashboard nie publikują własnych portów WWW na hoście. Są osiągalne dla NPM po nazwach DNS w sieci Docker `proxy`:

```text
zabbix-web-nginx:8080
wazuh-dashboard:5601
```

Publiczne porty webowe należą do NPM:

```text
80/tcp
81/tcp
443/tcp
```

## Wspólna MariaDB

Jeden kontener `shared-db` przechowuje osobne bazy i konta dla NPM oraz Zabbixa. Trwale ustawione jest:

```ini
log_bin_trust_function_creators=1
```

## Wazuh Dashboard RW

Plik:

```text
/opt/wazuh-persistent/dashboard/wazuh.yml
```

jest montowany RW, więc zmiany wykonane w GUI pozostają po restarcie.

## Własne reguły Wazuh

```text
files/wazuh/custom_rules/*.xml
files/wazuh/custom_decoders/*.xml
```

Katalogi mogą być puste. Po zmianach uruchom ponownie:

```bash
./run.sh
```

## Kontrola

```bash
docker ps

docker exec single-node-wazuh.manager-1 \
  /var/ossec/bin/wazuh-analysisd -t

docker exec shared-db \
  mariadb -uroot -p -e \
  "SHOW VARIABLES LIKE 'log_bin_trust_function_creators';"
```

## Czyszczenie

```bash
sudo ./cleanup_fresh.sh
```

Skrypt usuwa kontenery, wolumeny i dane aplikacji. Docker oraz Zabbix Agent 2 pozostają zainstalowane.

## Licencja

Kod automatyzacji jest udostępniany na licencji MIT. Komponenty zewnętrzne zachowują własne licencje.
