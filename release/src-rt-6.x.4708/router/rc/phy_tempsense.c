/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 *
 * Copyright 2011, ASUSTeK Inc.
 * All Rights Reserved.
 * 
 * THIS SOFTWARE IS OFFERED "AS IS", AND ASUS GRANTS NO WARRANTIES OF ANY
 * KIND, EXPRESS OR IMPLIED, BY STATUTE, COMMUNICATION OR OTHERWISE. BROADCOM
 * SPECIFICALLY DISCLAIMS ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A SPECIFIC PURPOSE OR NONINFRINGEMENT CONCERNING THIS SOFTWARE.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/time.h>
#include <unistd.h>
#include <bcmnvram.h>
#include <shared.h>
#include <shutils.h>
#include <wlutils.h>

//#define DEBUG

#define FAN_NORMAL_PERIOD	5 * 1000	/* microsecond */
#define TEMP_MAX		94.000
#define TEMP_3			88.000
#define TEMP_2			82.000
#define TEMP_1			76.000
#define TEMP_MIN		70.000
#define TEMP_H			3.000

#define max(a,b)  (((a) > (b)) ? (a) : (b))
#define min(a,b)  (((a) < (b)) ? (a) : (b))

static int count = -2;
static int status = -1;
static int duty_cycle = 0;
static int status_old = 0;
static double tempavg_24 = 0.000;
static double tempavg_50 = 0.000;
static double tempavg_max = 0.000;
static struct itimerval itv;
static int count_timer = 0;
static int base = 1;

static void
alarmtimer(unsigned long sec, unsigned long usec)
{
	itv.it_value.tv_sec  = sec;
	itv.it_value.tv_usec = usec;
	itv.it_interval = itv.it_value;
	setitimer(ITIMER_REAL, &itv, NULL);
}

static int
fan_status()
{
	int idx;

	if (!base)
		return 1;
	else if (base == 1)
		return 0;
	else
		idx = count_timer % base;

	if (!idx)
		return 0;
	else
		return 1;
}

static void
phy_tempsense_exit(int sig)
{
	alarmtimer(0, 0);
	led(LED_BRIDGE, LED_OFF);

        remove("/var/run/phy_tempsense.pid");
        exit(0);
}

static int
phy_tempsense_mon()
{
	char buf[WLC_IOCTL_SMLEN];
	char buf2[WLC_IOCTL_SMLEN];
	char w[32];
	int ret;
	unsigned int *ret_int = NULL;
	unsigned int *ret_int2 = NULL;

	strcpy(buf, "phy_tempsense");
	strcpy(buf2, "phy_tempsense");

	if ((ret = wl_ioctl("eth1", WLC_GET_VAR, buf, sizeof(buf))))
		return ret;

	if ((ret = wl_ioctl("eth2", WLC_GET_VAR, buf2, sizeof(buf2))))
		return ret;

	ret_int = (unsigned int *)buf;
	ret_int2 = (unsigned int *)buf2;

	if (count == -2)
	{
		count++;
		tempavg_24 = *ret_int;
		tempavg_50 = *ret_int2;
	}
	else
	{
		tempavg_24 = (tempavg_24 * 4 + *ret_int) / 5;
		tempavg_50 = (tempavg_50 * 4 + *ret_int2) / 5;
	}
#if 0
	tempavg_max = (((tempavg_24) > (tempavg_50)) ? (tempavg_24) : (tempavg_50));
#else
	tempavg_max = (tempavg_24 + tempavg_50) / 2;
#endif
#ifdef DEBUG
	dbG("phy_tempsense 2.4G: %d (%.3f), 5G: %d (%.3f), Max: %.3f\n", 
		*ret_int, tempavg_24, *ret_int2, tempavg_50, tempavg_max);
#endif
	duty_cycle = nvram_get_int("fanctrl_dutycycle");
	if ((duty_cycle < 0) || (duty_cycle > 5))
		duty_cycle = 0;

	if (duty_cycle && (tempavg_max < TEMP_MAX))
	{
		base = duty_cycle;
	}
	else
	{
		if (tempavg_max < TEMP_MIN - TEMP_H)
			base = 1;
		else
		if ((tempavg_max > TEMP_MIN) && (tempavg_max < TEMP_1 - TEMP_H))
			base = 2;
		else
		if ((tempavg_max > TEMP_1) && (tempavg_max < TEMP_2 - TEMP_H))
			base = 3;
		else
		if ((tempavg_max > TEMP_2) && (tempavg_max < TEMP_3 - TEMP_H))
			base = 4;
		else
		if ((tempavg_max > TEMP_3) && (tempavg_max < TEMP_MAX - TEMP_H))
			base = 5;
		else
		if (tempavg_max > TEMP_MAX)
			base = 0;
	}

	if (!base) {
		nvram_set("fanctrl_dutycycle_ex", "5");
	} else {
		sprintf(w, "%d", base - 1);
		nvram_set("fanctrl_dutycycle_ex", w);
	}

	return 0;
}

static void
phy_tempsense(int sig)
{
	int count_local = count_timer % 30;

	if (!count_local)
		phy_tempsense_mon();

        status_old = status;
        status = fan_status();
#ifdef DEBUG
	dbG("tempavg: %.3f, fan status: %d\n", tempavg_max, status);
#endif

	if (status != status_old)
	{
		if (status)
			led(LED_BRIDGE, LED_ON);
		else
			led(LED_BRIDGE, LED_OFF);
	}

	count_timer = (count_timer + 1) % 60;

	alarmtimer(0, FAN_NORMAL_PERIOD);
}

static void
update_dutycycle(int sig)
{
	alarmtimer(0, 0);

	count = -1;
	status = -1;
	count_timer = 0;

	duty_cycle = nvram_get_int("fanctrl_dutycycle");
	if ((duty_cycle < 0) || (duty_cycle > 5))
		duty_cycle = 0;

#ifdef DEBUG
	dbG("\nduty cycle: %d\n", duty_cycle);
#endif

	phy_tempsense(sig);
}

int 
phy_tempsense_main(int argc, char *argv[])
{
	FILE *fp;
	sigset_t sigs_to_catch;
	char w[32];

	/* write pid */
	if ((fp = fopen("/var/run/phy_tempsense.pid", "w")) != NULL)
	{
		fprintf(fp, "%d", getpid());
		fclose(fp);
	}

	/* set the signal handler */
	sigemptyset(&sigs_to_catch);
	sigaddset(&sigs_to_catch, SIGALRM);
	sigaddset(&sigs_to_catch, SIGTERM);
	sigaddset(&sigs_to_catch, SIGUSR1);
	sigprocmask(SIG_UNBLOCK, &sigs_to_catch, NULL);

	signal(SIGALRM, phy_tempsense);
	signal(SIGTERM, phy_tempsense_exit);
	signal(SIGUSR1, update_dutycycle);

	sprintf(w, "%d", base);
	nvram_set("fanctrl_dutycycle_ex", w);

	duty_cycle = nvram_get_int("fanctrl_dutycycle");
	if ((duty_cycle < 0) || (duty_cycle > 4))
		duty_cycle = 0;

#ifdef DEBUG
	dbG("\nduty cycle: %d\n", duty_cycle);
#endif

	alarmtimer(0, FAN_NORMAL_PERIOD);

	/* Most of time it goes to sleep */
	while (1)
	{
		pause();
	}

	return 0;
}

void
restart_fanctrl()
{
	kill_pidfile_s("/var/run/phy_tempsense.pid", SIGUSR1);	
}

