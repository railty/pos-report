rem schtasks /delete /tn "print-receipt" /f
rem schtasks /create /xml print-receipt.xml /tn "print-receipt" /ru sning /rp shawnN
rem schtasks /run /tn "print-receipt"

echo %1 %2 >c:\sites\pos-report\reports_to_be_generated
schtasks /run /tn "print-receipt"
