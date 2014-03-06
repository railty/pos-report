echo "start batch"
Call C:\RailsInstaller\Ruby1.9.3\setup_environment.bat C:\RailsInstaller
cd C:\Sites\pos-report\
ruby generate_reports.rb ALP 2014/01/02
echo "finish batch"