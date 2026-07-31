# Security Monitoring Ansible V7

Automatyczne wdrożenie na Ubuntu 24.04+ lub Debianie 13+: Wazuh 4.14.6, reguły SOCFortress, Zabbix 7.0 LTS, Zabbix Agent 2 na hoście, Nginx Proxy Manager oraz wspólna MariaDB.

## Najważniejsze zmiany V7

- provisioning NPM wykonuje się przy każdym uruchomieniu i jest idempotentny; nie używa już markera,
- usunięcie lub odtworzenie bazy NPM nie pozostawia fałszywej informacji, że routing już istnieje,
- jeden katalog bazowy może przechowywać konfigurację oraz trwałe dane aplikacji,
- świeże wdrożenie może trzymać dane na osobnym dysku zamontowanym np. pod `/data`,
- istniejący plik `all.yml` bez nowej zmiennej zachowuje nazwane wolumeny Dockera, aby aktualizacja V6 nie przełączyła usług na puste katalogi.

## Adresy

```text
http://IP/zabbix/
http://IP/wazuh/
https://IP/zabbix/
https://IP/wazuh/
http://IP:81/
```

HTTPS po IP używa certyfikatu self-signed. Transmisja jest szyfrowana, ale przeglądarka zgłosi niezaufanego wystawcę do czasu dodania certyfikatu lub lokalnego CA do zaufanych.

## Wybór miejsca na dane

Domyślny układ zachowuje katalogi pod `/opt`:

```yaml
security_monitoring_data_root: /opt
security_monitoring_bind_persistent_data: true
```

Dla osobnego dysku zamontowanego pod `/data` ustaw przed pierwszym wdrożeniem:

```yaml
security_monitoring_data_root: /data/security-monitoring
security_monitoring_required_mountpoint: /data
security_monitoring_bind_persistent_data: true
```

Przykładowy układ:

```text
/data/security-monitoring/shared-database/data
/data/security-monitoring/nginx-proxy-manager/data
/data/security-monitoring/nginx-proxy-manager/letsencrypt
/data/security-monitoring/zabbix/data
/data/security-monitoring/wazuh
/data/security-monitoring/wazuh-persistent
/data/security-monitoring/wazuh-socfortress
```

Pod wybraną ścieżkę trafiają trwałe dane MariaDB, NPM, Zabbixa i Wazuh oraz pliki Compose i konfiguracje. Obrazy kontenerów, warstwy zapisywalne i logi silnika Docker nadal znajdują się w `data-root` Dockera, zwykle `/var/lib/docker`.

Przed wdrożeniem sprawdź montowanie dysku:

```bash
findmnt /data
df -h /data
```

Ustawienie `security_monitoring_required_mountpoint: /data` zatrzyma playbook, jeżeli punkt montowania nie jest aktywny. Dysk powinien być montowany przez `/etc/fstab` przed startem Dockera. Jeżeli `/data` nie zostanie zamontowane, Linux utworzy zwykły katalog na partycji systemowej i kontenery mogą zapisać dane w złym miejscu.

### Aktualizacja istniejącej V6

Stary `group_vars/all.yml` nie zawiera `security_monitoring_bind_persistent_data`. Playbook przyjmie wtedy `false` i zachowa istniejące nazwane wolumeny. Nie włączaj bind-mountów na działającej instalacji bez wcześniejszej migracji danych.

## Instalacja

```bash
cp group_vars/all.yml.example group_vars/all.yml
chmod 600 group_vars/all.yml
nano group_vars/all.yml
./run.sh
```

## NPM i routing

Provisioner przy każdym uruchomieniu:

- tworzy brakujący Proxy Host dla IP,
- aktualizuje zarządzane ścieżki `/zabbix/` i `/wazuh/`,
- zachowuje dodatkowe domeny, Custom Locations i certyfikat dodane ręcznie,
- nie wykonuje zapisu, gdy konfiguracja jest już zgodna.

Po ręcznej zmianie hasła administratora NPM zaktualizuj również `npm_admin_password` w `group_vars/all.yml`, ponieważ playbook używa tych danych do API NPM.

## Zabbix Agent 2

Agent działa jako usługa systemowa. W Zabbix Web sprawdź:

```text
Data collection -> Hosts -> Zabbix server -> Interfaces
```

Ustaw adres IP VM i port `10050`. `127.0.0.1` z perspektywy kontenera Zabbix Server wskazuje sam kontener, a nie host z Agentem 2.

Konfiguracja agenta może pozostać:

```ini
Server=127.0.0.1,172.16.0.0/12
ServerActive=127.0.0.1
Hostname=Zabbix server
ListenIP=0.0.0.0
```

## Czyszczenie środowiska testowego

```bash
sudo ./cleanup_fresh.sh
```

Skrypt odczytuje katalog bazowy z `group_vars/all.yml`. Usuwa dane stosu, ale pozostawia Docker oraz Zabbix Agent 2.
