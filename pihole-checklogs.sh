#!/usr/bin/env bash

# pihole-cheklogs.sh
# Requires a full working Pi-hole environment, Bash 4+, GNU grep and zcat.
#
# Check Pi-hole FTL-DB and DNS logs for a list of given domains/IPs, in order to
# determine if they have ever been queried by Pi-hole system.
# This is notably useful to investigate on (or check for) possible compromise, based
# on a list of network indicators of compromise (IOCs).
# See checklogs_usage (or run pihole-checkloogs.sh --help) function for details.
#
# Licensed under AGPL-3.0-only License [https://www.gnu.org/licenses/agpl-3.0.en.html].
# Copyright (C) 2021, @securechicken
# Version: $Id$

# Variables
# Caller script name to show in help output (default value, read later from $0)
CALLER_SCRIPT="pihole-checklogs.sh"
# Pi-hole root scripts folder location
readonly PIHOLE_OPT="/opt/pihole"
# Pi-hole FTL and dnsmaq confs location
readonly PIHOLE_FTLCONF="/etc/pihole/pihole-FTL.conf"
readonly PIHOLE_DNSCONF="/etc/dnsmasq.d/01-pihole.conf"
# Pi-hole FTL DB sqlite3 file path (default value, read later from PIHOLE_FTLCONF)
PIHOLE_FTLDB="/etc/pihole/pihole-FTL.db"
readonly PIHOLE_FTLDB_CONF_SETTING="DBFILE"
# Pi-hole DNS log file path (default value, read later from PIHOLE_DNSCONF)
PIHOLE_LOGS="/var/log/pihole.log"
readonly PIHOLE_DNSLOGS_CONF_SETTING="log-facility"
HAS_DNSLOGS=true
# Do we also match subdomains of provided FQDNs/domains, ie. if "github.com" is given as
# IOC (but why?), also matches "api.github.com" and "gist.github.com" (default value,
# read later from args)
FQDN_MATCH_SUBDOMAINS=true
# Do we show results without asking user if wanted (default value, read later from args)
DEFAULT_SHOW_RESULTS=false
# Do we show info messages (default value, read later from args)
DEFAULT_SHOW_INFO=false
# Parsing helper constants
readonly FQDN_REGEX='^(([a-zA-Z0-9](-{,2}[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$'
readonly IP4_REGEX='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$'
readonly IP6_REGEX='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'
# Input data (IOCs) storage
declare -a TAB_IP=()
declare -a TAB_FQDN=()
declare -a TAB_ALIENS=()
# Results storage
RESULTS_FQDN_FTLDB=""
RESULTS_FQDN_DNS=""
RESULTS_IP_DNS=""
# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERR_CLI_USAGE=10
readonly EXIT_MSG_CLI_USAGE="Error: no arguments were provided"
readonly EXIT_ERR_INVALID_INPUT=11
readonly EXIT_MSG_INVALID_INPUT="Error: input <IOCs list> does not exist or is not readable"
readonly EXIT_ERR_FTLDB_FILE=20
readonly EXIT_MSG_FTLDB_FILE="Error: FTL DB file does not exist"
readonly EXIT_ERR_FTLDB_QUERY=21
readonly EXIT_MSG_FTLDB_QUERY="Error: FTL DB query failed"
readonly EXIT_ERR_DNSLOGS_QUERY=22
readonly EXIT_MSG_DNSLOGS_QUERY="Error: DNS logs search failed"

# Dependencies: import color printing
readonly PIHOLE_COLORS_DEF="${PIHOLE_OPT}/COL_TABLE"
if [[ -f "${PIHOLE_COLORS_DEF}" ]]; then
  # shellcheck source=/opt/pihole/COL_TABLE
  # shellcheck disable=SC1091
  source "${PIHOLE_COLORS_DEF}"
else
  readonly COL_NC=''
  readonly COL_GRAY=''
  readonly COL_RED=''
  readonly COL_GREEN=''
  readonly COL_YELLOW=''
  readonly COL_CYAN=''
  readonly TICK="[✓]"
  readonly CROSS="[✗]"
  readonly INFO="[i]"
fi

#######################################
# Prints usage help.
# Globals:
#   read: CALLER_SCRIPT
# Arguments: None
# Outputs:
#   Script usage info, to STDOUT
# Returns: None
#######################################
function checklogs_usage() {
  cat <<END
Usage: ${CALLER_SCRIPT} {--help|-h, <IOCs list> (--nosubs) (--results) (--info)}

Check Pi-hole FTL-DB and DNS logs for a list of given domains/IPs, in order to
determine if they have ever been queried by Pi-hole systems.
This is notably useful to investigate on (or check for) possible compromise, based
on a list of network indicators of compromise (IOCs).

-h, --help:   shows command-line usage info.
<IOCs list>:  a path to a file containing FQDNs, domains or IPv4/6 (one per line)
              with optional [.] defanging.
              The script will first search domains/FQDNs (and their subdomains by
              default) in Pi-hole's long term data (FTL DB). If matches are found, they
              are then searched in Pi-hole's DNS queries log (which is generated by
              dnsmasq by default) to obtain the queries' dates, clients and resolved
              IPs. IPv4/6 are searched as resolutions in the DNS logs directly.
--nosubs:     optional flag. If set, subdomains of the given domains/FQDNs are not
              searched.
--results:    optional flag. Show detailed results without prompting the user.
--info:       optional flag. Show more info messages.
END
}

#######################################
# Prints error message to STDERR.
# Globals:
#   read: CROSS, from ${PIHOLE_OPT}/COL_TABLE
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDERR
# Returns: None
#######################################
function perr() {
  echo -e "  ${CROSS} $1" >&2
}

#######################################
# Prints warning message to STDOUT.
# Globals:
#   read: COL_* from ${PIHOLE_OPT}/COL_TABLE
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDOUT
# Returns: None
#######################################
function pwarn() {
  echo -e "  [${COL_YELLOW}!${COL_NC}] $1"
}

#######################################
# Prints info message to STDOUT.
# Globals:
#   read: INFO and COL_* from ${PIHOLE_OPT}/COL_TABLE, DEFAULT_SHOW_INFO
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDOUT
# Returns: None
#######################################
function pinfo() {
  if [[ "${DEFAULT_SHOW_INFO}" == true ]]; then
    echo -e "  ${INFO} ${COL_GRAY}$1${COL_NC}"
  fi
}

#######################################
# Prints bad news to STDOUT.
# Globals:
#   read: CROSS, from ${PIHOLE_OPT}/COL_TABLE
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDOUT
# Returns: None
#######################################
function pbadnews() {
  echo -e "  ${CROSS} ${COL_RED}$1${COL_NC}"
}

#######################################
# Prints good news to STDOUT.
# Globals:
#   read: TICK and COL_* from ${PIHOLE_OPT}/COL_TABLE
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDOUT
# Returns: None
#######################################
function pgoodnews() {
  echo -e "  ${TICK} ${COL_GREEN}$1${COL_NC}"
}

#######################################
# Prints a question.
# Globals:
#   read: QST and COL_* from ${PIHOLE_OPT}/COL_TABLE
# Arguments:
#   Message to print out, a string
# Outputs:
#   Message, to STDOUT
# Returns: None
#######################################
function pquestion() {
  echo -e "  ${QST} ${COL_CYAN}$1${COL_NC}"
}

#######################################
# Prints a space-separated list of elements, one element by line, with prefix spaces.
# Globals: None
# Arguments:
#   Space separated list of elements, a string
# Outputs:
#   Table elments, to STDOUT
# Returns: None
#######################################
function ptable() {
  local a_element=""
  for a_element in $1; do
    echo "      ${a_element}"
  done
}

#######################################
# Get content of configuration setting definition, if exists.
# Globals: None
# Arguments:
#   Configuration file to read from, a path
#   Setting to look for, a string
#   Default value if setting is not set, a string
# Outputs:
#   Value of setting in configuration file, or default value if not set, to STDOUT
# Returns: None
#######################################
function get_conf_setting() {
  local found_setting="$3"
  if [[ -e "$1" ]]; then
    local grep_setting=""
    if grep_setting="$(grep "^\s*$2\s*=" "$1")" && [[ -n "${grep_setting}" ]]; then
      found_setting="${grep_setting##*=}"
      found_setting="${found_setting// }"
    fi
  fi
  echo "${found_setting}"
}

#######################################
# Parse input <IOCs file> and fill tables with content.
# Globals:
#   read: FQDN_REGEX, IP4_REGEX, IP6_REGEX, DEFAULT_SHOW_INFO
#   written: TAB_FQDN, TAB_IP, TAB_ALIENS
# Arguments:
#   A path to a line-separated file containing FQDNs, domains or IPv4/6, with or without
#     [.] protections
# Outputs:
#   Parsed content, to STDOUT
# Returns: None
#######################################
function parse_iocs_file() {
  # Parsing input IOCs and feeding tables with them
  local ioc_line=""
  while read -r ioc_line; do
    if [[ -n "${ioc_line}" ]]; then
      # Trim leading spaces
      ioc_line="${ioc_line##*( )}"
      # Trim trailing spaces
      ioc_line="${ioc_line%%*( )}"
      # Replace protections (ie. [.] by .)
      ioc_line="${ioc_line//[\[\]]/}"
      # Check if IP or FQDN, and add it to check lists
      if [[ "${ioc_line}" =~ ${FQDN_REGEX} ]]; then
        TAB_FQDN[${#TAB_FQDN[*]}]="${ioc_line}"
      elif [[ "${ioc_line}" =~ ${IP4_REGEX} || "${ioc_line}" =~ ${IP6_REGEX} ]]; then
        TAB_IP[${#TAB_IP[*]}]="${ioc_line}"
      else
        TAB_ALIENS[${#TAB_ALIENS[*]}]="${ioc_line}"
      fi
    fi
  done < "$1"
  # Print parsed FQDNs/domains and IPs
  if [[ "${DEFAULT_SHOW_INFO}" == true ]]; then
    if [[ "${#TAB_FQDN[*]}" -gt 0 ]]; then
      pinfo "Will check for these FQDNs:"
      ptable "${TAB_FQDN[*]}"
    fi
    if [[ "${#TAB_IP[*]}" -gt 0 ]]; then
      pinfo "Will check for these IPs:"
      ptable "${TAB_IP[*]}"
    fi
  fi
  # Warn if aliens found
  if [[ "${#TAB_ALIENS[*]}" -gt 0 ]]; then
    pwarn "Warning, ignored from <IOCs file>: ${TAB_ALIENS[*]}"
  fi
}

#######################################
# Grep DNS logs.
# Globals:
#   read: PIHOLE_LOGS
# Arguments:
#   An ERE regex to be searched with grep, a string
#   If grep should give 1 context line before matched line, a boolean
# Outputs:
#   Grep results, to STDOUT
#   Errors if any, to STDERR
# Returns: One of EXIT_ERR_* constants in case of error
#######################################
function grep_dns_logs() {
  local grep_query="$1"
  local grep_results=""
  local grep_command="grep -E -i -h"
  if [[ "$2" == true ]]; then
    grep_command="${grep_command} -B 1"
  fi
  grep_results="$(zcat -f -c "${PIHOLE_LOGS}"* | ${grep_command} "${grep_query}" 2>&1)"
  if [[ "$?" -le 1 ]]; then
    echo "${grep_results}"
  else
    perr "${EXIT_MSG_DNSLOGS_QUERY}"
    echo "      ${grep_query}" >&2
    echo "      ${grep_results}" >&2
    exit ${EXIT_ERR_DNSLOGS_QUERY} >&2
  fi
}

#######################################
# Check FTL DB for matching FQDNs/domains.
# Globals:
#   read: FQDN_MATCH_SUBDOMAINS, TAB_FQDN, PIHOLE_FTLDB, PIHOLE_LOGS, HAS_DNSLOGS
#   written: RESULTS_FQDN_FTLDB, RESULTS_FQDN_DNS
# Arguments: None
# Outputs:
#   Info messages, to STDOUT
#   Error messages on exit, to STDERR
# Returns: One of EXIT_ERR_* constants in case of error
#######################################
function check_domains() {
  pinfo "Checking for FQDNs/domains in FTL DB..."
  # Building SQL query for Pi-hole FTL DB
  local where_cond=""
  local a_fqdn=""
  if [[ "${FQDN_MATCH_SUBDOMAINS}" == true ]]; then
    for a_fqdn in "${TAB_FQDN[@]}"; do
      where_cond="${where_cond}(domain LIKE '%${a_fqdn}')"
    done
    where_cond="${where_cond//)(/) OR (}"
  else
    pinfo "--nosubs flag is set, will look for exact matches only"
    for a_fqdn in "${TAB_FQDN[@]}"; do
      where_cond="${where_cond}'${a_fqdn}'"
    done
    where_cond="${where_cond//\'\'/\', \'}"
    where_cond="domain IN (${where_cond})"
  fi
  local ftl_query="SELECT DISTINCT timestamp,domain,client FROM queries WHERE ( ${where_cond} )"
  # Executing sqlite3 command in FTL DB
  local sql_results=""
  # If results found, print, store results, and then look for details in DNS queries logs
  if sql_results="$(sqlite3 "${PIHOLE_FTLDB}" "${ftl_query}" 2>&1)"; then
    if [[ -n "${sql_results}" ]]; then
      RESULTS_FQDN_FTLDB="${sql_results}"
      local matched_fqdns=""
      matched_fqdns="$(echo "${RESULTS_FQDN_FTLDB}" | cut -d "|" -f 2 | sort | uniq)"
      pbadnews "Uh oh, some FQDNs matched"
      local fqdns_grep="${matched_fqdns//[$'\t\r\n']/ }"
      fqdns_grep="${fqdns_grep//./\\.}"
      fqdns_grep="${fqdns_grep// /|}"
      local grep_query="(query\[\w+\]|reply|cached)\s+(${fqdns_grep})\s"
      if [[ "${HAS_DNSLOGS}" == true ]]; then
        pinfo "Checking for FQDNs/domains in DNS queries logs..."
        local grep_results=""
        grep_results="$(grep_dns_logs "${grep_query}" false)"
        if [[ -n "${grep_results}" ]]; then
          RESULTS_FQDN_DNS="${grep_results}"
          pinfo "Additional results were found in DNS logs"
        else
          pwarn "No additional results were found in DNS logs"
        fi
      fi
    else
      pgoodnews "No FQDNs/domains were found in FTL DB"
    fi
  else
    perr "${EXIT_MSG_FTLDB_QUERY}"
    echo "      ${ftl_query}" >&2
    echo "      ${sql_results}" >&2
    exit ${EXIT_ERR_FTLDB_QUERY}
  fi
}

#######################################
# Check DNS logs for matching IPs.
# Globals:
#   read: TAB_IP, PIHOLE_LOGS
#   written: RESULTS_IP_DNS
# Arguments: None
# Outputs:
#   Info messages, to STDOUT
#   Error messages on exit, to STDERR
# Returns: One of EXIT_ERR_* constants in case of error
#######################################
function check_ips() {
  pinfo "Checking for IPs in DNS queries logs..."
  local ips_grep="${TAB_IP[*]//./\\.}"
  ips_grep="${ips_grep// /|}"
  local grep_query="is\s+(${ips_grep})$"
  local grep_results=""
  grep_results="$(grep_dns_logs "${grep_query}" true)"
  if [[ -n "${grep_results}" ]]; then
    RESULTS_IP_DNS="${grep_results}"
    pbadnews "Uh oh, some IPs matched"
  else
    pgoodnews "No IPs were found in DNS logs"
  fi
}

#######################################
# Display search results to user after confirmation.
# Globals:
#   read: RESULTS_*, DEFAULT_SHOW_RESULTS
# Arguments: None
# Outputs:
#   Raw results, to STDOUT
# Returns: One of EXIT_ERR_* constants in case of error
#######################################
function show_results() {
  local actually_show_results="${DEFAULT_SHOW_RESULTS}"
  if [[ "${actually_show_results}" == false ]]; then
    pquestion "Type any key to display detailed results (will exit in 10s otherwise)..."
    if read -r -s -n 1 -t 10 _; then
      actually_show_results=true
    fi
  fi
  if [[ "${actually_show_results}" == true ]]; then
    if [[ -n "${RESULTS_FQDN_FTLDB}" ]]; then
      pwarn "FQDNs/domains in FTL DB"
      echo "${RESULTS_FQDN_FTLDB}"
    fi
    if [[ -n "${RESULTS_FQDN_DNS}" ]]; then
      pwarn "FQDNs/domains in DNS Logs"
      echo "${RESULTS_FQDN_DNS}"
    fi
    if [[ -n "${RESULTS_IP_DNS}" ]]; then
      pwarn "IPs in DNS Logs"
      echo "${RESULTS_IP_DNS}"
    fi
  fi
}

#######################################
# Entry point MAIN.
# Globals:
#   read: PIHOLE_FTLCONF, PIHOLE_DNSCONF, PIHOLE_FTLDB_CONF_SETTING,
#         PIHOLE_DNSLOGS_CONF_SETTING, PIHOLE_LOGS_CAT, FQDN_REGEX, IP4_REGEX, IP6_REGEX,
#         EXIT_* constants
#   written: PIHOLE_FTLDB, PIHOLE_LOGS, FQDN_MATCH_SUBDOMAINS, TAB_*, RESULTS_*,
#            HAS_DNSLOGS
# Arguments:
#   Script call arguments are expected, see checklogs_usage.
# Outputs:
#   Operation results, to STDOUT
#   Errors and failure, to STDERR
# Returns:
#   EXIT_OK on success, one of EXIT_ERR_* constants otherwise.
#######################################
function main() {
  # Shows usage info if requested
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    checklogs_usage
    exit ${EXIT_OK}
  fi
  # Check for input file argument existence
  local infile_path="$1"
  if [[ ! -f "${infile_path}" ]]; then
    perr "${EXIT_MSG_INVALID_INPUT}"
    echo "      ${infile_path}" >&2
    exit ${EXIT_ERR_INVALID_INPUT}
  fi
  shift
  # Parse other args/options
  local outfile_path=""
  if [[ $# -ge 1 ]]; then
    local a_arg=""
    for a_arg in "${@}"; do
      case "${a_arg}" in
        "--nosubs")
          FQDN_MATCH_SUBDOMAINS=false
          ;;
        "--results")
          DEFAULT_SHOW_RESULTS=true
          ;;
        "--info")
          DEFAULT_SHOW_INFO=true
          ;;
        *)
          pwarn "Unknown argument: ${a_arg}"
          ;;
      esac
    done
  fi

  # Parse <IOCs list> file input
  parse_iocs_file "${infile_path}"

  # Retrieving PIHOLE_FTLDB and PIHOLE_LOGS from configuration files if set
  PIHOLE_FTLDB="$(get_conf_setting "${PIHOLE_FTLCONF}" "${PIHOLE_FTLDB_CONF_SETTING}" "${PIHOLE_FTLDB}")"
  if [[ ! -f "${PIHOLE_FTLDB}" ]]; then
    perr "${EXIT_MSG_FTLDB_FILE}"
    echo "      ${PIHOLE_FTLDB}" >&2
    exit ${EXIT_ERR_FTLDB_FILE}
  fi
  pinfo "Using FTL DB: ${PIHOLE_FTLDB}"
  PIHOLE_LOGS="$(get_conf_setting "${PIHOLE_DNSCONF}" "${PIHOLE_DNSLOGS_CONF_SETTING}" "${PIHOLE_LOGS}")"
  if [[ ! -f "${PIHOLE_LOGS}" ]]; then
    HAS_DNSLOGS=false
    pwarn "Warning, DNS logs file does not exist: ${PIHOLE_LOGS}"
    pwarn "IPs and queries details will not be searched"
  else
    pinfo "Using DNS logs: ${PIHOLE_LOGS}"
  fi

  if [[ "${#TAB_FQDN[*]}" -eq 0 && "${#TAB_IP[*]}" -eq 0 ]]; then
    pwarn "No FQDN/domain or IP in input IOCs file..."
  else
    # Checking FTL DB for FQDNs/domains, and in DNS logs if results found in FTL DB
    if [[ "${#TAB_FQDN[*]}" -gt 0 ]]; then
      check_domains
    fi
    # Checking DNS logs for IPs
    if [[ "${#TAB_IP[*]}" -gt 0 && "${HAS_DNSLOGS}" == true ]]; then
      check_ips
    fi
  fi

  # Show results if any
  if [[ -n "${RESULTS_FQDN_FTLDB}" || \
        -n "${RESULTS_FQDN_DNS}" || \
        -n "${RESULTS_IP_DNS}" ]]; then
    show_results "${outfile_path}"
  fi

  exit ${EXIT_OK}
}

# Get caller script name to show in help output
CALLER_SCRIPT="${0##*/}"

# Exit with error and show usage if no arguments, start with main otherwise
if [[ "$#" -eq 0 ]]; then
  perr "${EXIT_MSG_CLI_USAGE}"
  checklogs_usage
  exit ${EXIT_ERR_CLI_USAGE}
else
  main "$@"
  exit ${EXIT_OK}
fi
