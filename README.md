# Security Monitoring – Ansible

Wdrożenie dla Ubuntu 24.04+ i Debian 13+.

Instaluje:

- Docker Engine i Docker Compose,
- Wazuh 4.14.6 single-node,
- SOCFortress,
- własne reguły i dekodery Wazuh,
- Zabbix 7.0 LTS: Server i frontend Nginx,
- Zabbix Agent 2 bezpośrednio na hoście,
- Nginx Proxy Manager,
- jedną wspólną MariaDB dla NPM i Zabbixa.

Nie ma dodatkowego kontenera `path-gateway`. Porty 80 i 443 obsługuje bezpośrednio Nginx Proxy Manager.

## Architektura

```text
MariaDB
├── baza npm
└── baza zabbix

Nginx Proxy Manager
├── /         -> zabbix-web-nginx:8080
├── /zabbix/  -> przekierowanie do /
└── /wazuh/   -> wazuh-dashboard:5601
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

## Przygotowanie repozytorium

Plik z hasłami nie powinien trafić do GitHuba. Repozytorium zawiera:

```text
group_vars/all.yml.example
```

Utwórz lokalną konfigurację:

```bash
cp group_vars/all.yml.example group_vars/all.yml
chmod 600 group_vars/all.yml
nano group_vars/all.yml
```

`group_vars/all.yml` jest wpisany do `.gitignore`.

Plik zawiera proste hasła domyślne przeznaczone do testów. Nie trzeba dodawać znaków specjalnych.

Dla haseł baz danych dozwolone jest 1-128 znaków: litery, cyfry oraz:

```text
_ . @ ! # % + = : -
```

Hasło administratora NPM może być dowolnym tekstem o długości 8-64 znaków. Jest to minimalne ograniczenie samego Nginx Proxy Managera.

## Pierwsze uruchomienie

Przy przejściu ze starszego wariantu, który miał `path-gateway`, osobną bazę NPM i `zabbix-db`, wykonaj pełne czyszczenie:

```bash
sudo ./cleanup_fresh.sh
```

Następnie:

```bash
chmod +x run.sh cleanup_fresh.sh
./run.sh
```

## Adresy

```text
Zabbix:               http://IP/
Zabbix alias:         http://IP/zabbix/  (przekierowanie do /)
Wazuh:                http://IP/wazuh/
Nginx Proxy Manager:  http://IP:81
```

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

Domyślne hasła baz danych, używane wewnętrznie przez kontenery:

```text
MariaDB root: rootpassword
NPM DB:       npmpassword
Zabbix DB:    zabbixpassword
```

Są to dane do laboratorium i testów. W środowisku docelowym zmień je przed pierwszym uruchomieniem.

NPM tworzy przy pierwszym uruchomieniu Proxy Host dla adresu IP. Głównym backendem jest oficjalny frontend Zabbixa `zabbix-web-nginx:8080`, a Custom Location `/wazuh/` kieruje do `wazuh-dashboard:5601`. Ścieżka `/zabbix/` przekierowuje do `/`. Provisioning korzysta z endpointów API NPM i jest wykonywany tylko raz dla danej wersji konfiguracji.

Dane NPM są ustawione w:

```text
group_vars/all.yml
```

Zmienne:

```yaml
npm_admin_email: admin@example.com
npm_admin_password: '...'
```

Po pierwszym logowaniu możesz w tym samym Proxy Hoście dodać nazwę domenową i certyfikat. Przed włączeniem `Force SSL` usuń adres IP z pola `Domain Names` albo utwórz osobny Proxy Host dla domeny — certyfikat publiczny zwykle nie obejmuje adresu IP.

Playbook nie nadpisuje późniejszych zmian, ponieważ tworzy marker:

```text
/opt/nginx-proxy-manager/.ip-routing-v4-provisioned
```

## Dostęp do paneli WWW

Frontend Zabbixa i Wazuh Dashboard nie publikują portów WWW na interfejsach hosta. Oba kontenery są osiągalne przez nazwę DNS wyłącznie w sieci Docker `proxy`, a publiczne porty 80 i 443 należą do Nginx Proxy Managera.

Nazwa obrazu i nazwa kontenera to różne pola. Frontend używa oficjalnego obrazu:

```text
zabbix/zabbix-web-nginx-mysql:alpine-7.0-latest
```

i działa jako kontener:

```text
zabbix-web-nginx
```

Zabbix działa w katalogu głównym `/`, ponieważ jego frontend nie jest przebudowywany pod niestandardową ścieżkę. Dzięki temu logowanie i ciasteczka sesyjne działają bez dodatkowych modyfikacji obrazu.

## Wspólna MariaDB

Jeden kontener `shared-db` przechowuje osobne bazy i konta dla NPM oraz Zabbixa.

Trwale ustawione jest:

```ini
log_bin_trust_function_creators=1
```

Konfiguracja:

```text
/opt/shared-database/99-shared-database.cnf
```

## Zabbix Agent 2

Agent 2 jest instalowany na hoście i działa przez systemd.

Domyślna nazwa:

```yaml
zabbix_agent_hostname: Zabbix server
```

Playbook jednorazowo aktualizuje domyślny interfejs hosta `Zabbix server` w GUI:

```text
DNS: host.docker.internal
Port: 10050
```

Dzięki temu kontener `zabbix-server` nie próbuje łączyć się z własnym `127.0.0.1`.

Kontrola:

```bash
systemctl status zabbix-agent2 --no-pager
ss -lntp | grep ':10050'
```

## Wazuh Dashboard RW

Plik:

```text
/opt/wazuh-persistent/dashboard/wazuh.yml
```

jest montowany jako RW. Zmiany wykonane w GUI Wazuh, np. adres używany w instrukcji wdrażania agentów, pozostają po restarcie.

## Własne detekcje Wazuh

Reguły:

```text
files/wazuh/custom_rules/*.xml
```

Dekodery:

```text
files/wazuh/custom_decoders/*.xml
```

Katalogi mogą być puste. Nie twórz XML-a zawierającego wyłącznie pustą grupę.

Po zmianach:

```bash
./run.sh
```

## Kontrola

```bash
sudo docker ps

sudo docker exec single-node-wazuh.manager-1 \
  /var/ossec/bin/wazuh-analysisd -t

systemctl status zabbix-agent2 --no-pager

sudo docker exec shared-db \
  mariadb -uroot -p -e \
  "SHOW VARIABLES LIKE 'log_bin_trust_function_creators';"
```

Brak wyniku z `wazuh-analysisd -t` oznacza poprawną konfigurację reguł i dekoderów.

## Czyszczenie

```bash
sudo ./cleanup_fresh.sh
```

Skrypt usuwa kontenery, wolumeny i dane aplikacji. Docker oraz pakiet Zabbix Agent 2 pozostają zainstalowane.

## Licencja

Kod automatyzacji jest udostępniany na licencji MIT. Komponenty zewnętrzne zachowują własne licencje.
