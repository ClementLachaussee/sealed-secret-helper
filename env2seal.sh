Help()
{
	# Display Help
	echo
	echo "Syntax: env2bash [-h | -c config-file -f envFileName | -n target-namespace -N controller-namespace -C controller-name -f envFileName -s secret-name -S sealed-secret-name -o output-dir]"
	echo "options:"
	echo "-h     Print this help."
	echo "-c     Use the specified configuration file."
	echo "-f     Path to the environment variable file."
	echo "-n     Namespace where the secret will be created."
	echo "-N     Namespace containing the sealed-secret controller, defaulting to 'kube-system'."
	echo "-C     Name of the sealed-secret controller, defaulting to 'sealed-secrets-controller'."
	echo "-s     Name of the secret to be created."
	echo "-S     Name of the sealed-secret to be created, defaulting to the secret name."
	echo "-o     Output directory path, defaulting to ./"
}

if ! command -v kubectl &> /dev/null; then
    echo "[E] kubectl could not be found. Please install it."
    exit
fi

#if ! command -v kubeseal &> /dev/null; then
#    echo "[E] kubeseal could not be found. Please install it."
#    exit
#fi

#
while getopts ":hn:N:C:f:c:s:S:o:" option; do
  case $option in
    h) # display Help
			Help
      exit;;
    n) # Enter a name
      namespace=$OPTARG;;
		N) 
			controllerNamespace=$OPTARG;;
		C)
			controllerName=$OPTARG;;
		f)
			envFileName=$OPTARG;;
		c)
			configFile=$OPTARG;;
		s) 
			secretName=$OPTARG;;
		S)
			sealedSecretName=$OPTARG;;
		o)
			output=$OPTARG;;
    \?) # Invalid option
      echo "[E] Invalid option."
			Help
      exit;;
  esac
done

if ! [[ -z $configFile ]]; then
	export $(grep -v '^#' $configFile | xargs)
fi

if ! [[ -z $controllerNamespace ]]; then
	export E2S_CONTROLLER_NAMESPACE=$controllerNamespace
fi

if ! [[ -z $controllerName ]]; then
	export E2S_CONTROLLER_NAME=$controllerName
fi

if ! [[ -z $secretName ]]; then
	export E2S_SECRET_NAME=$secretName
fi

if ! [[ -z $sealedSecretName ]]; then
	export E2S_SEALED_SECRET_NAME=$sealedSecretName
fi

if ! [[ -z $namespace ]]; then
	export E2S_NAMESPACE=$namespace
fi

if ! [[ -z $envFileName ]]; then
	export E2S_ENV_FILE_NAME=$envFileName
fi

if ! [[ -z $output ]]; then
	export E2S_OUTPUT=$output
fi 


if [[ -z $E2S_SECRET_NAME ]]; then
	echo "[E] E2S_SECRET_NAME is empty. A secret name must be provided."
	Help
	exit
fi

if [[ -z $E2S_SEALED_SECRET_NAME ]]; then
	echo "[I] E2S_SEALED_SECRET_NAME is empty. The sealed-secret will be called the secret name : $E2S_SECRET_NAME-sealed in a file named $E2S_SECRET_NAME-sealed.yaml"
	E2S_SEALED_SECRET_NAME=$E2S_SECRET_NAME-sealed
fi

if [[ -z $E2S_CONTROLLER_NAMESPACE ]]; then
	echo "[I] No value provided for E2S_CONTROLLER_NAMESPACE, defaulting to 'kube-system'."
	E2S_CONTROLLER_NAMESPACE="kube-system"
fi

if [[ -z $E2S_CONTROLLER_NAME ]]; then
	echo "[I] No value provided for E2S_CONTROLLER_NAME, defaulting to 'sealed-secrets-controller'."
	E2S_CONTROLLER_NAME="sealed-secrets-controller"
fi

if [[ -z $E2S_NAMESPACE ]]; then
	ns=$(kubectl config view --minify -o jsonpath='{..namespace}')
	if [[ -z $ns ]]; then
		echo "[E] No value provided for E2S_NAMESPACE. A namespace must be provided."
		Help
		exit
	fi
	E2S_NAMESPACE=$ns
	echo "[I] No value provided for E2S_NAMESPACE, defaulting to current namespace $E2S_NAMESPACE"
fi

if [[ -z $E2S_ENV_FILE_NAME ]]; then 
	echo "[E] No value provided for E2S_ENV_FILE_NAME. An environment variable file must be provided."
	Help
	exit
fi

if [[ -z $E2S_OUTPUT ]]; then
	E2S_OUTPUT='./'
	echo "[I] No value provided for E2S_OUTPUT, defaulting to $E2S_OUTPUT"
fi

echo "[I] Configuration loaded :"
echo "[I] E2S_SECRET_NAME=$E2S_SECRET_NAME" 
echo "[I] E2S_SEALED_SECRET_NAME=$E2S_SEALED_SECRET_NAME" 
echo "[I] E2S_CONTROLLER_NAME=$E2S_CONTROLLER_NAME" 
echo "[I] E2S_CONTROLLER_NAMESPACE=$E2S_CONTROLLER_NAMESPACE" 
echo "[I] E2S_NAMESPACE=$E2S_NAMESPACE" 
echo "[I] E2S_ENV_FILE_NAME=$E2S_ENV_FILE_NAME"
echo "[I] E2S_OUTPUT=$E2S_OUTPUT"

echo "[D] kubectl create secret generic -o yaml --dry-run=client -n $E2S_NAMESPACE $E2S_SECRET_NAME --from-env-file=$E2S_ENV_FILE_NAME > $E2S_OUTPUT$E2S_SECRET_NAME.yaml"

kubectl create secret generic -o yaml --dry-run=client -n $E2S_NAMESPACE $E2S_SECRET_NAME --from-env-file=$E2S_ENV_FILE_NAME > $E2S_OUTPUT$E2S_SECRET_NAME.yaml

kubeseal --controller-name=$E2S_CONTROLLER_NAME \ 
		--controller-namespace=$E2S_CONTROLLER_NAMESPACE \
		-o yaml \
		--name=$E2S_SEALED_SECRET_NAME < $E2S_OUTPUT$E2S_SECRET_NAME.yaml > $E2S_OUTPUT$E2S_SEALED_SECRET_NAME.yaml

#rm -f $E2S_OUTPUT$E2S_SECRET_NAME.yaml