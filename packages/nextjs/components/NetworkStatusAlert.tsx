"use client";

import { useEffect, useState } from "react";

interface NetworkStatus {
  isRunning: boolean;
  networkType: string;
  message: string;
  severity: "info" | "warning" | "error";
}

export const NetworkStatusAlert = () => {
  const [networkStatus, setNetworkStatus] = useState<NetworkStatus | null>(null);
  const [isVisible, setIsVisible] = useState(true);

  useEffect(() => {
    const fetchNetworkStatus = async () => {
      try {
        const response = await fetch('/network-status.json');
        if (response.ok) {
          const data = await response.json();
          setNetworkStatus(data);
        }
      } catch (error) {
        console.error("Error fetching network status:", error);
      }
    };

    fetchNetworkStatus();
  }, []);

  if (!networkStatus || !isVisible) return null;

  const alertClasses = {
    info: "alert alert-info",
    warning: "alert alert-warning",
    error: "alert alert-error",
  };

  return (
    <div className="sticky top-0 z-50">
      <div className={alertClasses[networkStatus.severity]}>
        <div className="flex w-full justify-between items-center">
          <div className="flex items-center">
            {networkStatus.severity === 'info' && (
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" className="stroke-current shrink-0 w-6 h-6 mr-2">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            )}
            {networkStatus.severity === 'warning' && (
              <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current shrink-0 h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            )}
            {networkStatus.severity === 'error' && (
              <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current shrink-0 h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            )}
            <span>{networkStatus.message}</span>
          </div>
          <button 
            className="btn btn-ghost btn-sm" 
            onClick={() => setIsVisible(false)}
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
};

export default NetworkStatusAlert;