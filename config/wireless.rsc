# jan/02/1970 00:42:57 by RouterOS 6.18
# software id = 8E9X-W5NG
#
/interface bridge
add l2mtu=1600 name=goddard-bridge
add l2mtu=1596 name=uksa-bridge
/interface ethernet
set [ find default-name=ether1 ] name=ether1-local
/interface vlan
add interface=ether1-local l2mtu=1596 name=uksa-vlan use-service-tag=yes \
    vlan-id=1
/interface wireless security-profiles
add authentication-types=wpa2-psk management-protection=allowed mode=\
    dynamic-keys name=goddard wpa2-pre-shared-key=rogerwilco
/interface wireless
set [ find default-name=wlan1 ] band=2ghz-b/g/n channel-width=\
    20/40mhz-ht-above disabled=no frequency=2412 hide-ssid=yes l2mtu=2290 \
    mode=ap-bridge name=goddard-ap security-profile=goddard ssid=goddard
add disabled=no l2mtu=2290 mac-address=4E:5E:0C:D6:2C:84 master-interface=\
    goddard-ap name=uksa-ap ssid=MAMAConnect
/ip neighbor discovery
set goddard-ap discover=no
/ip pool
add name=default-dhcp ranges=192.168.88.10-192.168.88.254
/ip dhcp-server
add address-pool=default-dhcp disabled=no interface=ether1-local lease-time=\
    10m name=default
/interface bridge port
add bridge=goddard-bridge interface=ether1-local
add bridge=goddard-bridge interface=goddard-ap
add bridge=uksa-bridge interface=uksa-vlan
add bridge=uksa-bridge interface=uksa-ap
/ip address
add address=192.168.88.10/24 comment="default configuration" interface=\
    ether1-local network=192.168.88.0
/ip dhcp-client
add comment="default configuration" dhcp-options=hostname,clientid disabled=\
    no interface=goddard-ap
/ip dhcp-server network
add address=192.168.88.0/24 comment="default configuration" dns-server=\
    192.168.88.1 gateway=192.168.88.1
/ip dns
set allow-remote-requests=yes
/ip dns static
add address=192.168.88.1 name=router
/ip firewall filter
add chain=input comment="default configuration" protocol=icmp
add chain=input comment="default configuration" connection-state=established
add chain=input comment="default configuration" connection-state=related
add action=drop chain=input comment="default configuration" in-interface=\
    goddard-ap
add chain=forward comment="default configuration" connection-state=\
    established
add chain=forward comment="default configuration" connection-state=related
add action=drop chain=forward comment="default configuration" \
    connection-state=invalid
/ip firewall nat
add action=masquerade chain=srcnat comment="default configuration" \
    out-interface=goddard-ap
/ip upnp
set allow-disable-external-interface=no
/system leds
set 0 interface=goddard-ap
/system routerboard settings
set cpu-frequency=600MHz
/tool mac-server
set [ find default=yes ] disabled=yes
add interface=ether1-local
/tool mac-server mac-winbox
set [ find default=yes ] disabled=yes
add interface=ether1-local
